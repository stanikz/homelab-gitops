# Cloud-Init

Each VM receives its configuration through Cloud-Init.

The configuration is generated dynamically from:

```
modules/proxmox-vm/cloud-init/common.yaml.tftpl
```

Values are rendered by OpenTofu using:

```hcl
templatefile(...)
```

Current responsibilities:

- Hostname
- Timezone
- User creation
- SSH keys
- Password hash (You need to create or set your hash password under terraform.tfvars and make sure its in .gitignore)
- Containerd installation
- Kernel modules
- sysctl configuration
- Swap removal