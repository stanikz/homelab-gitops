# Changelog

## Unreleased

### Added

* S3-compatible remote OpenTofu state backend using RustFS
* Native S3 state locking
* Runtime backend credential retrieval from Bitwarden
* Terragrunt Bitwarden wrapper script
* DNS configuration for Kubernetes nodes
* Common node troubleshooting utilities

### Changed

* OpenTofu dependency lock files are now tracked in Git
* Terraform state is stored remotely instead of in the local Terragrunt cache

### Planned

* Kubernetes bootstrap with kubeadm
* Cilium
* Argo CD
* OpenBao

## v0.1.0

* Initial repository
* OpenTofu module
* Terragrunt
* Proxmox VM provisioning
* Cloud-Init support