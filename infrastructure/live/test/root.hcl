locals {
  proxmox_endpoint  = get_env("PROXMOX_VE_ENDPOINT")
  proxmox_api_token = get_env("PROXMOX_VE_API_TOKEN")
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/proxmox-vm"

  extra_arguments "tfvars" {
    commands  = get_terraform_commands_that_need_vars()
    arguments = ["-var-file=${find_in_parent_folders("terraform.tfvars")}"]
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "proxmox" {
  endpoint  = "${local.proxmox_endpoint}"
  api_token = "${local.proxmox_api_token}"
  insecure  = true
}
EOF
}