# 🏠 🌐  home-infrastructure

> Infrastructure as code repository for my home

## 🚀 Quickstart

```bash
# Install prerequisites
brew install ansible kubeseal terraform
```

```bash
# Configure 1Password Account ID
echo "OP_ACCOUNT=$(op account get --format json | jq ".id")" > .env
```

> ℹ️ Use IntelliJ run configurations to provision & bootstrap the cluster.
> Everything else is automated by Flux.

## ⭐ Overview

* [`provisioning`](./provisioning) – Ansible configuration to provision the k3s cluster
* [`bootstrap`](./bootstrap) – Terraform configuration to bootstrap the k3s cluster setup
* [`cluster`](./cluster) – Flux cluster configuration entrypoint
* [`infrastructure`](./infrastructure) – Manifests for infrastructure components
* [`apps`](./apps) – Manifests for apps
