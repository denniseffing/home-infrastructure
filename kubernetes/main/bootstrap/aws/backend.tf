terraform {
  backend "kubernetes" {
    namespace        = "aws"
    secret_suffix    = "state"
    config_path      = "~/.kube/config"
  }
}
