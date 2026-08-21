# OpenTofu & Terragrunt

Infrastructure is provisioned using:

* OpenTofu
* Terragrunt

The reusable VM module lives in:

```text
infrastructure/modules/proxmox-vm
```

Terragrunt environments live under:

```text
infrastructure/live/
```

## Remote State

OpenTofu state is stored remotely in a RustFS S3-compatible object storage backend.

The backend configuration is defined in:

```text
infrastructure/live/test/root.hcl
```

The state bucket is:

```text
tofu-state
```

Each Terragrunt unit receives its own state file using:

```hcl
key = "${path_relative_to_include()}/terraform.tfstate"
```

For example:

```text
proxmox/k8s/cpl-01/terraform.tfstate
proxmox/k8s/wrk-01/terraform.tfstate
proxmox/k8s/wrk-02/terraform.tfstate
```

State locking is enabled using the S3 lockfile mechanism.

Remote state prevents Terraform/OpenTofu state from being tied to the local
`.terragrunt-cache` directory.

## Backend Authentication

RustFS credentials are stored in Bitwarden and retrieved at runtime.

Credentials are not stored in:

* Git
* Terragrunt configuration
* OpenTofu configuration
* state files

The wrapper script used for Terragrunt commands is:

```text
scripts/terragrunt-bw.sh
```

The script retrieves the RustFS access key and secret key from Bitwarden and exports them as:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

before starting Terragrunt.

## Requirements

The wrapper requires:

* Bitwarden CLI (`bw`)
* `jq`
* Terragrunt
* an unlocked Bitwarden vault

Unlock Bitwarden first:

```bash
bw unlock
```

Export the returned session:

```bash
export BW_SESSION="<session-token>"
```

## Common Workflow

Review:

```bash
./scripts/terragrunt-bw.sh run --all plan \
  --working-dir infrastructure/live/test
```

Deploy:

```bash
./scripts/terragrunt-bw.sh run --all apply \
  --working-dir infrastructure/live/test
```

Destroy:

```bash
./scripts/terragrunt-bw.sh run --all destroy \
  --working-dir infrastructure/live/test
```


## Dependency Lock Files

`.terraform.lock.hcl` files are committed to Git.

They pin provider selections and checksums so OpenTofu uses consistent provider
versions across machines and rebuilds.

The following should remain ignored:

```gitignore
.terraform/
.terragrunt-cache/
*.tfstate
*.tfstate.*
```

The following should not be ignored:

```text
.terraform.lock.hcl
```

## Important

Do not store backend credentials directly in `root.hcl`, `backend.tf`, or
Terraform variable files.

Terraform/OpenTofu state may contain sensitive values and must be treated as
sensitive infrastructure data.
