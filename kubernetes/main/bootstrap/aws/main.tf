terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.32.1"
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
