locals {
  proxmox_endpoint  = get_env("PROXMOX_VE_ENDPOINT")
  proxmox_api_token = get_env("PROXMOX_VE_API_TOKEN")
}

inputs = {
  bridge                      = "vmbr0"
  datastore_id                = "local-zfs"
  initialization_datastore_id = "local-zfs"
  template_vm_id              = 5000 #Template must exist in PROXMOX
  dns_servers                 = ["192.168.10.151"] #Change this to your DNS server @home
  dns_search_domain           = "home" #this can be specific to your internal DNS @home

  cpu_type        = "x86-64-v2-AES"
  keyboard_layout = "sv"
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

  ssh {
    agent    = true
    username = "root"
  }
}
EOF
}