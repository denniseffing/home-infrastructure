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

## ⭐ Overview

* [`kubernetes/main/bootstrap/k3s`](./provisioning) – Ansible configuration to provision the k3s cluster
* [`kubernetes/main/bootstrap/infrastructure`](./kubernetes/main/bootstrap) – Helmfile configuration to bootstrap infrastructure components
* [`kubernetes/main/cluster`](./kubernetes/main/cluster) – Flux cluster configuration entrypoint
* [`kubernetes/main/infrastructure`](./kubernetes/main/infrastructure) – Manifests for infrastructure components
* [`kubernetes/main/apps`](./kubernetes/main/apps) – Manifests for apps

## ❤️ Thanks

Thanks to all the awesome people in the [Home Operations](https://discord.gg/home-operations) 
Discord community and the [k8s-at-home](https://github.com/topics/k8s-at-home) GitHub topic for
providing inspiration and guidance.
Special thanks to [@onedr0p](https://github.com/onedr0p) for maintaining awesome
[rootless container images](https://github.com/onedr0p/containers) and his genius 
[home-ops](https://github.com/onedr0p/home-ops) setup!
