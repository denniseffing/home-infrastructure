<div align="center">

# 🏠 🌐  home-infrastructure

</div>

<div align="center">

[![Kubernetes](https://kromgo.denniseffing.de/badges/kubernetes_version)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://kromgo.denniseffing.de/badges/flux_version)](https://fluxcd.io)&nbsp;&nbsp;

</div>

<div align="center">

[![Age](https://kromgo.denniseffing.de/badges/cluster_birth_age)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;
[![Uptime](https://kromgo.denniseffing.de/badges/cluster_uptime_age)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;
[![Nodes](https://kromgo.denniseffing.de/badges/cluster_node_count)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;
[![Pods](https://kromgo.denniseffing.de/badges/cluster_pod_count)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;
[![CPU](https://kromgo.denniseffing.de/badges/cluster_cpu_usage)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;
[![Memory](https://kromgo.denniseffing.de/badges/cluster_memory_usage)](https://github.com/home-operations/kromgo)&nbsp;&nbsp;

_Infrastructure as code repository for my home_
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

```sh
📁 k3s                   # ansible configuration to provision the cluster
📁 bootstrap             # helmfile configuration to bootstrap infrastructure
📁 kubernetes
├── 📁 apps              # applications
├── 📁 components        # flux entrypoints
└── 📁 infrastructure    # infrastructure components
```

## ❤️ Thanks

Thanks to all the awesome people in the [Home Operations](https://discord.gg/home-operations) 
Discord community and the [k8s-at-home](https://github.com/topics/k8s-at-home) GitHub topic for
providing inspiration and guidance.
Special thanks to [@onedr0p](https://github.com/onedr0p) for maintaining awesome
[rootless container images](https://github.com/home-operations/containers) and his genius 
[home-ops](https://github.com/onedr0p/home-ops) setup!
