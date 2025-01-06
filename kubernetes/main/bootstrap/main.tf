terraform {
  required_version = ">= 1.9.0"

  backend "kubernetes" {
    secret_suffix    = "state"
    config_path      = "~/.kube/config"
    config_context   = "home"
    namespace = "flux-system"
  }

  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "1.4.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "2.1.0"
    }
  }
}

resource "flux_bootstrap_git" "this" {
  components_extra = ["image-reflector-controller", "image-automation-controller"]
  embedded_manifests = true
  path               = "kubernetes/main/cluster"
  kustomization_override = file("${path.root}/resources/flux-kustomization-patch.yaml")
}

data "onepassword_item" "flux_deploy_key" {
  vault = "fqmjd474lbyob5bjsxmhomwk5i"
  title = "Flux Deploy Key"
}
