terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
  }

  backend "kubernetes" {
    namespace        = "aws"
    secret_suffix    = "state"
    config_path      = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "home"
}

provider "aws" {
  region = "eu-central-1"
}
