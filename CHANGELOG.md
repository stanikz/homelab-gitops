# Changelog

## Unreleased

### Added

* S3-compatible remote OpenTofu state backend using RustFS
* Native S3 state locking
* Runtime backend credential retrieval from Bitwarden
* Terragrunt Bitwarden wrapper script
* DNS configuration for Kubernetes nodes
* Common node troubleshooting utilities
* Ansible inventory and bootstrap automation for Kubernetes nodes
* Kubernetes node prerequisite role
* containerd installation and configuration role
* Pinned containerd version
* systemd cgroup configuration for containerd

### Changed

* OpenTofu dependency lock files are now tracked in Git
* Terraform state is stored remotely instead of in the local Terragrunt cache
* Kubernetes host preparation is managed with Ansible instead of manual shell steps

### Planned

* Kubernetes package installation (`kubelet`, `kubeadm`, `kubectl`)
* kubeadm control-plane initialization
* Worker node join
* Cilium
* Argo CD
* OpenBao

## v0.1.0

* Initial repository
* OpenTofu module
* Terragrunt
* Proxmox VM provisioning
* Cloud-Init support