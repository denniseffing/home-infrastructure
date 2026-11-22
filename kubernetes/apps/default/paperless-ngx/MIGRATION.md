# Migrate Paperless from Redis to Valkey

Paperless will start with an empty Valkey broker. No Redis data will be copied
or restored. Drain queued jobs before stopping Paperless: jobs left in Redis
will not run on Valkey. This does not change Paperless's application data volumes.

Valkey provisioning, the broker switch, and Redis manifest removal are in one
commit. **Do not push that
commit until step 2 is complete.** The live steps below keep Paperless off
during the switch and retain Redis for rollback. Run them against the intended
cluster with `kubectl` and `flux`. Stop on any failed check.

## 1. Verify the provisioned Valkey instance

Before replacing the provisioning-only revision on `origin/main`, confirm
Flux has deployed Valkey from that revision. Ensure the 1Password item
`paperless-ngx-valkey` has a `password` field, then check:

```bash
flux reconcile kustomization paperless-ngx-valkey -n flux-system --with-source
kubectl -n default wait --for=condition=Ready externalsecret/paperless-ngx-valkey --timeout=2m
kubectl -n default wait --for=condition=Ready helmrelease/paperless-ngx-valkey --timeout=5m
kubectl -n default rollout status deploy/paperless-ngx-valkey --timeout=5m
kubectl -n default get pvc paperless-ngx-valkey-data
```

Confirm the 1 GiB claim is `Bound` to `longhorn-encrypted`. Check that the
dedicated Valkey instance responds to `PING` and `INFO KEYSPACE` shows no
`dbN:` entries:

```bash
kubectl -n default exec deploy/paperless-ngx-valkey -c app -- sh -ec '
  export REDISCLI_AUTH="$VALKEY_PASSWORD"
  valkey-cli PING
  valkey-cli INFO KEYSPACE
'
```

If a previous migration attempt already loaded data into this instance, stop
and provision a fresh, empty dedicated Valkey volume before proceeding.

From the live Redis StatefulSet and its Redis container's volume mounts,
identify the exact data PVC. Record its bound PV and CSI volume handle as well
as the new Valkey PV and handle (use `kubectl get pv <name> -o yaml`). Confirm the old handle is a
Longhorn volume and is different from Valkey's. Keep these identifiers for
cleanup; do not select volumes based only on name prefixes.

## 2. Stop Paperless and protect Redis from pruning

Pause ingestion and let active and queued jobs finish. Record the Deployment's
replica count, then suspend the HelmRelease and scale it to zero. Leave the
Flux Kustomization running so it can apply the new ExternalSecret later.

```bash
kubectl -n default get deploy paperless-ngx -o jsonpath='{.spec.replicas}{"\n"}'
flux suspend helmrelease paperless-ngx -n default
kubectl -n default scale deploy/paperless-ngx --replicas=0
kubectl -n default get pods -l app.kubernetes.io/instance=paperless-ngx
```

Wait for **all** Paperless pods to terminate before switching brokers. Before
pushing the cutover commit, set the old PV's reclaim policy to `Retain` and
tell Flux to leave the old Redis resources running when its Kustomization
is removed:

```bash
kubectl patch pv OLD_REDIS_PV --type=merge -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
kubectl -n flux-system patch kustomization paperless-ngx-redis --type=merge \
  -p '{"spec":{"deletionPolicy":"Orphan"}}'
kubectl -n flux-system get kustomization paperless-ngx-redis -o jsonpath='{.spec.deletionPolicy}{"\n"}'
```

Replace `OLD_REDIS_PV` with the recorded name and confirm the deletion policy
reads `Orphan` before pushing.

## 3. Switch Paperless and bring it back up

Replace the provisioning-only revision using `--force-with-lease`, with the
expected remote commit pinned to the revision verified in step 1. Reconcile
`paperless-ngx` and wait for External
Secrets to write an updated `PAPERLESS_REDIS` before allowing any Paperless pod
to start:

```bash
flux reconcile kustomization paperless-ngx -n flux-system --with-source
kubectl -n default annotate externalsecret paperless-ngx force-sync="$(date +%s)" --overwrite
kubectl -n default get helmrelease paperless-ngx -o jsonpath='{.spec.suspend}{"\n"}'
kubectl -n default get pods -l app.kubernetes.io/instance=paperless-ngx
```

Expect `true` and zero pods. Check the new URL without printing its password:

```bash
kubectl -n default get secret paperless-ngx -o jsonpath='{.data.PAPERLESS_REDIS}' |
  base64 -d | python3 -c 'import sys; from urllib.parse import urlsplit; u = urlsplit(sys.stdin.read()); print(u.hostname, u.port or 6379, u.path or "/0")'
```

Resume only once it reports `paperless-ngx-valkey.default.svc.cluster.local`,
port `6379`, and `/0`:

```bash
flux resume helmrelease paperless-ngx -n default
flux reconcile helmrelease paperless-ngx -n default
kubectl -n default rollout status deploy/paperless-ngx --timeout=5m
```

Check the Deployment has returned to the recorded replica count (scale it back
if needed). Check the web UI, worker logs, and an end-to-end document ingestion.
Before Paperless writes to Valkey, you can roll back by restoring the
Paperless `app/` manifests, the Redis document in `ks.yaml`, and `redis/` from
the provisioning-only revision. Keep the Valkey resources in place. Reconcile
while Paperless is stopped, check that External Secrets
has restored the old URL, and resuming Paperless. After writes to Valkey, stop
Paperless first and reconcile the new job state before going back; the old
volume won't contain those changes.

## 4. Retire Redis and delete its old volume

Only after successful verification and when rollback storage is no longer
needed, confirm Flux has removed the `paperless-ngx-redis` Kustomization. Until
then, do not delete its HelmRelease: Flux could recreate it. Uninstall the
orphaned Redis HelmRelease, wait for its StatefulSet and pods to disappear,
then remove the orphaned chart source and ExternalSecret:

```bash
kubectl -n default delete helmrelease redis
# Verify the old Redis StatefulSet and pods are gone before continuing.
kubectl -n default delete ocirepository bitnami-redis
kubectl -n default delete externalsecret redis-credentials
```

Verify Paperless is still healthy. Do not touch the shared
Dawarich Valkey instance or any Paperless application-data claims.

The chart's StatefulSet PVC may outlive Helm uninstall. Substitute the exact
old identifiers recorded in step 1 and verify that the old claim (if present)
still points to the old PV, the PV points to the old handle, and no pod mounts
the claim. The following removes the retained backend **permanently**:

```bash
kubectl -n default delete pvc OLD_REDIS_PVC --ignore-not-found
# Confirm the old PV is Released and the Longhorn volume is detached first.
kubectl delete pv OLD_REDIS_PV
kubectl -n longhorn delete volumes.longhorn.io OLD_REDIS_CSI_HANDLE
```

Confirm the old PVC, PV, and Longhorn volume are gone and
`paperless-ngx-valkey-data` is still bound and healthy.
