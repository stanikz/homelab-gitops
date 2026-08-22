include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  name           = "k8s-cpl-01"
  node_name      = "pvg"
  vm_id          = 1000

  cpu_cores    = 2 #HW requirement (2vCPU) by kubeadm for control-plane node 
  memory_mb    = 2048
  disk_size_gb = 40

  ipv4_cidr = "192.168.10.170/24"
  gateway   = "192.168.10.1"

  ssh_public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}