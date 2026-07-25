# OpenTofu & Terragrunt

Infrastructure is provisioned using:

- OpenTofu
- Terragrunt

The reusable VM module lives in:

```
infrastructure/modules/proxmox-vm
```

Terragrunt environments live under:

```
infrastructure/live/
```

## Common workflow

Review:

```bash
terragrunt run --all plan
```

Deploy:

```bash
terragrunt run --all apply
```

Destroy:

```bash
terragrunt run --all destroy
```