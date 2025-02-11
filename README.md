<div align="center">

# 🏠 🌐  home-infrastructure
_Infrastructure as code repository for my home_

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.denniseffing.de%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;

</div>

## 🚀 Quickstart

```bash
# Install prerequisites
mise trust && mise install
```

```bash
# Provision cluster
task bootstrap:k3s
# Bootstrap infrastructure components on cluster
task bootstrap:infrastructure
```

```bash
# Configure 1Password Account ID for bootstrap
echo "OP_ACCOUNT=$(op account get --format json | jq ".id")" > .env

# Create namespace for bootstrap
kubectl create namespace flux-system
```

Now use the IntelliJ run configuration to bootstrap the cluster.
Afterward, Flux is doing the heavy lifting for you.

## ⭐ Overview

* [`provisioning`](./provisioning) – Ansible configuration to provision the k3s cluster
* [`kubernetes/main/bootstrap`](./kubernetes/main/bootstrap) – Terraform configuration to bootstrap the k3s cluster setup
* [`kubernetes/main/cluster`](./kubernetes/main/cluster) – Flux cluster configuration entrypoint
* [`kubernetes/main/infrastructure`](./kubernetes/main/infrastructure) – Manifests for infrastructure components
* [`kubernetes/main/apps`](./kubernetes/main/apps) – Manifests for apps
