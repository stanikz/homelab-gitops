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
* Kubernetes node prerequisite Ansible role
* containerd installation and configuration Ansible role
* Pinned containerd package version
* systemd cgroup configuration for containerd
* Kubernetes package repository configuration using `pkgs.k8s.io`
* Kubernetes package installation Ansible role
* Pinned Kubernetes `1.36.4` packages
* Automated installation of `kubelet`, `kubeadm`, and `kubectl`
* Package holds for Kubernetes components
* kubeadm control-plane configuration and validation
* Automated kubeadm control-plane initialization
* Administrative kubeconfig provisioning for the control-plane user
* Automated Kubernetes worker-node join
* Runtime generation of short-lived kubeadm join tokens
* Idempotent worker join validation using `/etc/kubernetes/kubelet.conf`

### Changed

* OpenTofu dependency lock files are now tracked in Git
* Terraform state is stored remotely instead of in the local Terragrunt cache
* Kubernetes host preparation is managed with Ansible instead of manual shell steps
* Kubernetes and container runtime versions are explicitly pinned for reproducible cluster builds
* Control-plane VM CPU allocation increased to satisfy kubeadm requirements

### Planned

* Cilium
* Cluster networking validation
* Argo CD
* OpenBao

## v0.1.0

* Initial repository
* OpenTofu module
* Terragrunt
* Proxmox VM provisioning
* Cloud-Init support
