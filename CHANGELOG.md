# Changelog

## Unreleased

### Added

* Argo CD installed via Ansible and Helm as the final bootstrap step
* app-of-apps root Application reconciling `gitops/platform/`
* `gitops/` directory for GitOps-managed cluster resources
* Cilium LB-IPAM with reserved pool `192.168.10.210`-`.240`
* Cilium L2 announcements on `eth0` for `LoadBalancer` service reachability

### Changed

* Cilium now runs in kube-proxy replacement mode
* kube-proxy is no longer installed (skipped at kubeadm init via `skipPhases`)
* Cilium install now sets `k8sServiceHost`/`k8sServicePort` (required with
  kube-proxy replacement)

### Planned

* Move Argo CD off port-forward (Cilium Gateway API + TLS)
* Improve Cilium Helm idempotency with the Ansible Helm module
* Evaluate Hubble
* OpenBao (secrets), monitoring, logging

## v0.2.0

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
* Kubernetes bootstrap wrapper script with Ansible connectivity validation
* Automatic SSH known-host refresh for rebuildable Kubernetes nodes
* Automatic local kubeconfig refresh after cluster rebuilds
* Cilium installation using Ansible and Helm
* Cilium role for Kubernetes CNI installation
* Dedicated Cilium installation playbook
* Kubernetes node readiness validation after CNI installation
* CoreDNS validation after Cilium installation
* Conditional CoreDNS restart handling after Cilium installation
* Validated end-to-end Kubernetes bootstrap after a clean VM rebuild
* Full bootstrap flow including Cilium after a clean VM rebuild

### Changed

* OpenTofu dependency lock files are now tracked in Git
* Terraform state is stored remotely in RustFS instead of the local Terragrunt cache
* Kubernetes host preparation is managed with Ansible instead of manual shell steps
* Kubernetes bootstrap is executed through `scripts/bootstrap-k8s.sh`
* Kubernetes and container runtime versions are explicitly pinned for reproducible cluster builds
* Control-plane VM CPU allocation increased to satisfy kubeadm requirements

## v0.1.0 (Historical milestone)

### Added

* Initial repository structure
* OpenTofu module for Proxmox virtual machine provisioning
* Terragrunt configuration
* Ubuntu Cloud-Init support