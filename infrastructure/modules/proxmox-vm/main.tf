resource "proxmox_virtual_environment_vm" "this" {
    name            = var.name
    node_name       = var.node_name
    vm_id           = var.vm_id
    description     = var.description
    tags            = var.tags
    keyboard_layout = var.keyboard_layout

    clone {
        vm_id = var.template_vm_id
        full = true
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
    boot_order = ["scsi0"]

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

        user_account {
            username = var.username
            password = var.ubuntu_password
            keys     = [trimspace(var.ssh_public_key)]
        }
    }
}
