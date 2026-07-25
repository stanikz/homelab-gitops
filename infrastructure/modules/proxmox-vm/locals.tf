locals {
  cloud_init_common = templatefile(
    "${path.module}/cloud-init/common.yaml.tftpl",
    {
      hostname       = var.name
      username       = var.username
      ssh_public_key = trimspace(var.ssh_public_key)
      timezone       = var.timezone
      user_password_hash = var.user_password_hash
    }
  )
}