terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "home"
}

provider "aws" {
  region = "eu-central-1"
}
