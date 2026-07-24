terraform {
  required_version = ">= 0.12"

  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "~> 0.111.1"
    }
  }
}
