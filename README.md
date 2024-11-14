# 🏠 🌐  home-infrastructure

> Infrastructure as code repository for my home

## 🚀 Quickstart

```bash
# Install prerequisites
brew install ansible kubeseal terraform
```

```bash
# Provision cluster
ansible-playbook -i provisioning/inventory.yaml provisioning/cluster.yaml
cilium install
cilium hubble enable --ui
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
* [`bootstrap`](./bootstrap) – Terraform configuration to bootstrap the k3s cluster setup
* [`cluster`](./cluster) – Flux cluster configuration entrypoint
* [`infrastructure`](./infrastructure) – Manifests for infrastructure components
* [`apps`](./apps) – Manifests for apps
