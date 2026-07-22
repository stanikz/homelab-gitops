variable "name" {
  type = string
}

variable "node_name" {
    type = string 
}

variable "vm_id" {
    type = number
}

variable "template_vm_id" {
    type = number
}

variable "datastore_id" {
    type = string
}

variable "bridge" {
    type = string
}

variable "cpu_cores" {
    type = number
    default = 2
}

variable "memory_mb" {
    type = number
    default = 2048
}

variable "disk_size_gb" {
    type = number
    default = 20 
}

variable "ipv4_cidr" {
    type = string
}

variable "gateway" {
    type = string
}

variable "ssh_public_key" {
    type = string
}

variable "username" {
    type = string
    default = ubuntu
}

variable "password" {
    type = string
    sensitive = true
}

variable "description" {
    type = string
    default = "Manged by OpenTofu!"
}

variable "tags" {
    type = list(string)
    default = ["terraform", "kubernetes"]
}