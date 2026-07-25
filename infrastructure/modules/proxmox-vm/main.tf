resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id  = var.snippets_datastore_id
  node_name     = var.node_name

  source_raw {
    data      = local.cloud_init_common
    file_name = "${var.name}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name            = var.name
  node_name       = var.node_name
  vm_id           = var.vm_id
  description     = var.description
  tags            = var.tags
  keyboard_layout = var.keyboard_layout

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
    iothread     = true #good for ZFS/SSD
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  agent {
    enabled = true
  }

  initialization {
    datastore_id = var.initialization_datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
  }
}