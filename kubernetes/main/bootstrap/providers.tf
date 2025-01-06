provider "flux" {
  kubernetes = {
    config_path = "~/.kube/config"
    config_context = "home"
  }
  git = {
    url = "ssh://github.com/denniseffing/home-infrastructure.git"
    ssh = {
      username = "git"
      private_key = data.onepassword_item.flux_deploy_key.private_key
    }
  }
}
