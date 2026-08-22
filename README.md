# Homelab GitOps

A GitOps-driven homelab built with OpenTofu, Terragrunt, Proxmox, Ansible and Kubernetes.

The purpose of this repository is to learn, experiment and build a
production-inspired Kubernetes platform using Infrastructure as Code (IaC),
configuration management and GitOps principles.

---

# Architecture

```text
                Git Repository
                      │
                      ▼
             OpenTofu + Terragrunt
                │             │
                │             └───────────────┐
                ▼                             ▼
           Proxmox VE                  RustFS Object Storage
                │                       Remote State
                │
         Clone Ubuntu Template
                │
                ▼
             Cloud-Init
                │
                ▼
              Ansible
                │
          ┌─────┴─────┐
          │           │
          ▼           ▼
      containerd   Kubernetes
                    packages
                        │
                        ▼
                     kubeadm
                        │
                        ▼
                      Cilium
                        │
                        ▼
                     Argo CD
                        │
                        ▼
              Applications & Platform
```

Infrastructure state is stored remotely in an S3-compatible RustFS bucket.

Backend credentials are retrieved from Bitwarden at runtime and are not stored in the repository.

Cloud-Init is responsible for the generic Ubuntu baseline, while Ansible manages Kubernetes-specific host configuration and cluster bootstrap.

---

# Technology Stack

| Component | Technology |
|-----------|------------|
| Infrastructure as Code | OpenTofu |
| Orchestration | Terragrunt |
| Hypervisor | Proxmox VE |
| Operating System | Ubuntu Server 24.04 LTS |
| Provisioning | Cloud-Init |
| Configuration Management | Ansible |
| Remote State | RustFS |
| Credential Management | Bitwarden CLI |
| Kubernetes | kubeadm `v1.36.4` |
| Container Runtime | containerd `2.2.1` |
| Networking | Cilium `1.20.1` (Helm Chart)|
| GitOps | Argo CD **(planned)** |
| Secrets Management | OpenBao **(planned)** |

---

# Repository Structure

```text
homelab-gitops/
├── CHANGELOG.md
├── LICENSE
├── README.md
├── ROADMAP.md
├── TODO.md
│
├── docs/
│   ├── architecture.md
│   ├── cilium.md
│   ├── cloud-init.md
│   ├── kubernetes-bootstrap.md
│   ├── proxmox-template.md
│   ├── repository-structure.md
│   ├── terraform.md
│   └── troubleshooting.md
│
├── infrastructure/
│   ├── live/                # Terragrunt environments
│   └── modules/             # Reusable OpenTofu modules
│
├── kubernetes/
│   └── ansible/
│       ├── ansible.cfg
│       ├── inventories/
│       ├── playbooks/
│       └── roles/
│           ├── k8s_prereq/
│           ├── containerd/
│           ├── k8s_packages/
│           ├── kubeadm_control_plane/
│           └── kubeadm_worker/
│
└── scripts/
    ├── bootstrap-k8s.sh             # Kubernetes bootstrap entry point
    ├── refresh-k8s-known-hosts.sh   # Refresh SSH host keys after VM rebuilds
    └── terragrunt-bw.sh             # Terragrunt wrapper with Bitwarden credentials
```

Future platform and application directories will be added when those stages are
implemented.

---

# Requirements

Install the following software before using this repository:

* Git
* OpenTofu
* Terragrunt
* Ansible
* OpenSSH
* Bitwarden CLI
* jq
* Helm

---

# Authentication

Provisioning uses separate authentication mechanisms for Proxmox and the remote
state backend.

## Proxmox API

OpenTofu authenticates against the Proxmox API using an API token.

Required environment variables:

```bash
export PROXMOX_VE_ENDPOINT="https://pve.example.com:8006/api2/json"
export PROXMOX_VE_API_TOKEN="user@realm!terraform=xxxxxxxx-xxxx-xxxx-xxxx"
```

## Proxmox SSH

Cloud-Init snippets are uploaded over SSH to the Proxmox node.

Verify that an SSH agent is running:

```bash
echo "$SSH_AUTH_SOCK"
```

Verify that an SSH identity is loaded:

```bash
ssh-add -L
```

If no identities are available:

```bash
ssh-add ~/.ssh/id_ed25519
```

Without a loaded SSH identity, provisioning of Cloud-Init snippets will fail.

## RustFS Remote State

OpenTofu state is stored in a RustFS S3-compatible backend.

RustFS credentials are stored in Bitwarden and retrieved at runtime using:

```text
scripts/terragrunt-bw.sh
```

Unlock Bitwarden:

```bash
bw unlock
```

Export the returned session:

```bash
export BW_SESSION="<session-token>"
```

Alternatively:

```bash
export BW_SESSION="$(bw unlock --raw)"
```

The wrapper retrieves the RustFS credentials and exposes them to OpenTofu as:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

The credentials are not stored in Git.

---

# Quick Start

## Clone the repository

```bash
git clone <repository-url>
cd homelab-gitops
```

## Export Proxmox credentials

```bash
export PROXMOX_VE_ENDPOINT="https://pve.example.com:8006/api2/json"
export PROXMOX_VE_API_TOKEN="user@realm!terraform=xxxxxxxx-xxxx-xxxx-xxxx"
```

## Load your SSH key

```bash
ssh-add ~/.ssh/id_ed25519
```

## Configure Cloud-Init User Password

The Cloud-Init user password is provided to OpenTofu as a SHA-512 password hash.

Generate a password hash:

```bash
openssl passwd -6
```

## Unlock Bitwarden

```bash
export BW_SESSION="$(bw unlock --raw)"
```

## Review the infrastructure

```bash
./scripts/terragrunt-bw.sh run --all plan \
  --working-dir infrastructure/live/test
```

## Deploy the infrastructure

```bash
./scripts/terragrunt-bw.sh run --all apply \
  --working-dir infrastructure/live/test
```

## Bootstrap Kubernetes

From the repository root, run:

```bash
./scripts/bootstrap-k8s.sh
```

The bootstrap wrapper performs the local orchestration required to configure the Kubernetes cluster:

1. Refreshes SSH host keys for the Kubernetes nodes.
2. Verifies Ansible connectivity.
3. Runs the Kubernetes bootstrap playbook.
4. Refreshes the local kubeconfig from the newly initialized control-plane node.
5. Installs Cilium as the cluster CNI.
6. Validates Cilium, node readiness and CoreDNS.

The Ansible automation then:

* Configures Kubernetes node prerequisites.
* Installs and configures containerd.
* Installs pinned Kubernetes packages.
* Initializes the kubeadm control plane.
* Provisions the administrative kubeconfig.
* Generates short-lived kubeadm join credentials.
* Joins worker nodes to the cluster.
* Installs Cilium with Helm.
* Waits for all Kubernetes nodes to become Ready.
* Validates CoreDNS.

The bootstrap script is the recommended entry point after provisioning or
rebuilding the Kubernetes virtual machines.

### Run Ansible directly

For development or troubleshooting, the Ansible commands can also be executed
directly.

Change into the Ansible directory:

```bash
cd kubernetes/ansible
```

Verify connectivity:

```bash
ansible kubernetes -m ping
```

Review the Ansible changes:

```bash
ansible-playbook playbooks/prepare-nodes.yml --check --diff
```

Run the bootstrap playbook:

```bash
ansible-playbook playbooks/prepare-nodes.yml
```

When using the playbook directly after recreating the virtual machines, SSH host keys may need to be refreshed first.

From the repository root:

```bash
./scripts/refresh-k8s-known-hosts.sh
```

## Install Cilium separately

Cilium is installed automatically by `scripts/bootstrap-k8s.sh`.

For development or troubleshooting, the Cilium playbook can also be executed
directly after the kubeadm bootstrap has completed and the local kubeconfig has been refreshed:

```bash
cd kubernetes/ansible
ansible-playbook playbooks/install-cilium.yml
```

The playbook:

* Adds the official Cilium Helm repository.
* Installs or upgrades Cilium with Helm.
* Waits for the Cilium DaemonSet rollout.
* Waits for the Cilium operator rollout.
* Waits for all Kubernetes nodes to become `Ready`.
* Validates CoreDNS.

Validate the cluster:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
```

Expected result:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

## Destroy the infrastructure

From the repository root, run:

```bash
./scripts/terragrunt-bw.sh run --all destroy \
  --working-dir infrastructure/live/test
```

---

# Current Features

## Infrastructure

* Reusable OpenTofu module for Proxmox VMs
* Terragrunt-managed environments
* Ubuntu template cloning
* Cloud-Init provisioning
* Static IP configuration
* DNS server and search-domain configuration
* SSH key injection
* Password hash support
* QEMU Guest Agent enabled
* Configurable CPU, memory and storage
* Parameterized VM configuration

## Remote State and Credentials

* RustFS S3-compatible remote state
* Native S3 state locking
* Bitwarden-backed backend authentication
* Runtime backend credential retrieval
* OpenTofu dependency lock files tracked in Git

## Kubernetes Bootstrap

* Ansible-managed Kubernetes node configuration
* Idempotent Kubernetes node prerequisite automation
* Swap disabled on Kubernetes nodes
* Required kernel modules configured
* Required sysctl values configured
* Pinned containerd installation
* containerd configured with systemd cgroups
* containerd enabled and managed by systemd
* Official Kubernetes `pkgs.k8s.io` repository
* Pinned Kubernetes `1.36.4` packages
* Automated installation of `kubelet`, `kubeadm`, and `kubectl`
* Kubernetes package holds to prevent unintended upgrades
* kubeadm control-plane configuration and validation
* Automated control-plane initialization
* Administrative kubeconfig provisioning
* Automated worker-node join
* Runtime generation of kubeadm join credentials
* Idempotent worker join detection
* Automatic SSH host-key refresh after Kubernetes VM rebuilds
* Kubernetes bootstrap wrapper with Ansible connectivity validation
* Common node troubleshooting utilities
* Local kubeconfig refresh after kubeadm cluster rebuilds
* Cilium installation using Ansible and Helm
* Cilium DaemonSet rollout validation
* Cilium operator rollout validation
* Kubernetes node readiness validation after CNI installation
* CoreDNS validation after Cilium installation
---

# Current Kubernetes Cluster

The current test environment consists of:

| Node | Role | Address |
|------|------|---------|
| `k8s-cpl-01` | Control Plane | `192.168.10.170` |
| `k8s-wrk-01` | Worker | `192.168.10.171` |
| `k8s-wrk-02` | Worker | `192.168.10.172` |

Kubernetes API endpoint:

```text
https://k8s-cpl-01.home:6443
```

Cluster networking is provided by Cilium.

Cilium is installed with Ansible using the official Helm chart. The current
installation keeps kube-proxy enabled.

After Cilium installation, all Kubernetes nodes are expected to reach the
`Ready` state and CoreDNS is expected to run successfully.

---

# Roadmap

## Stage 1 — Infrastructure

* [x] Repository structure
* [x] OpenTofu module
* [x] Terragrunt
* [x] Proxmox VM provisioning
* [x] Cloud-Init
* [x] Remote state backend
* [x] Backend credential management

## Stage 2 — Kubernetes Bootstrap

* [x] Kubernetes node preparation
* [x] containerd configuration
* [x] Kubernetes package installation
* [x] kubeadm control-plane bootstrap
* [x] Worker node join
* [x] Automated bootstrap entry point
* [x] Clean rebuild validation
* [x] Cilium
* [ ] Cluster validation

## Stage 3 — GitOps Platform

* [ ] Argo CD
* [ ] OpenBao
* [ ] Monitoring
* [ ] Logging

## Stage 4 — Applications

* [ ] GitOps applications
* [ ] Automated upgrades

---

# Configuration Responsibilities

The repository separates responsibilities between the provisioning layers.

## OpenTofu and Terragrunt

Responsible for infrastructure lifecycle management:

* Proxmox virtual machines
* CPU, memory and storage
* VM networking
* Cloud-Init configuration
* Remote state management

## Cloud-Init

Responsible for the generic Ubuntu operating system baseline:

* Base packages
* SSH access
* User configuration
* QEMU Guest Agent
* Generic troubleshooting utilities

Cloud-Init intentionally does not contain Kubernetes-specific configuration.

## Ansible

Responsible for Kubernetes-specific host configuration and bootstrap:

* Disabling swap
* Loading required kernel modules
* Applying Kubernetes sysctl configuration
* Installing and configuring containerd
* Installing Kubernetes packages
* Pinning package versions
* Initializing the kubeadm control plane
* Provisioning the administrative kubeconfig
* Joining worker nodes

This separation keeps the infrastructure and Kubernetes layers independently
maintainable and makes clean cluster rebuilds easier to reproduce.

---

# Reproducibility

Container runtime and Kubernetes package versions are explicitly pinned to make
cluster rebuilds deterministic.

The current bootstrap uses:

```text
Kubernetes: 1.36.4
containerd: 2.2.1
```

Kubernetes packages and containerd are held after installation to prevent
unintended upgrades.

`.terraform.lock.hcl` files are intentionally committed to Git so that OpenTofu
provider versions and checksums remain reproducible.

The Kubernetes bootstrap is designed to be repeatable after infrastructure
rebuilds. The `bootstrap-k8s.sh` entry point refreshes SSH host keys before
running Ansible so that recreated virtual machines using the same hostnames and addresses can be configured without retaining stale SSH host-key entries.

After a clean cluster rebuild, the local kubeconfig is refreshed from the
control-plane node before installing Cilium. This is required because kubeadm
generates a new Kubernetes certificate authority for the rebuilt cluster, and an old kubeconfig from a previous cluster will fail TLS verification against the new API server.

---

# Security

Sensitive information such as passwords, API tokens, backend credentials,
kubeadm join credentials and SSH private keys must never be committed to Git.

Backend credentials are retrieved from Bitwarden at runtime.

kubeadm worker join credentials are generated dynamically during the Ansible
bootstrap and are only used during execution.

## SSH Host Keys

The Kubernetes virtual machines are intentionally rebuildable and retain stable DNS names and IP addresses between rebuilds.

Recreating a virtual machine generates new SSH host keys. Existing entries in
the local SSH `known_hosts` file therefore become stale and would normally cause
SSH host identification errors.

The Kubernetes bootstrap wrapper handles this by running:

```text
scripts/refresh-k8s-known-hosts.sh
```

before Ansible connectivity is tested.

This behavior is intended for the controlled, rebuildable Kubernetes nodes in
this homelab environment.

---

# Notes

Cloud-Init configuration is generated dynamically from templates inside the
reusable OpenTofu module.

OpenTofu state is stored remotely in RustFS rather than inside the local
Terragrunt cache.

The recommended Kubernetes bootstrap entry point is:

```bash
./scripts/bootstrap-k8s.sh
```

The current Kubernetes cluster has completed the kubeadm bootstrap stage.

The complete infrastructure and Kubernetes bootstrap has been successfully
validated from a clean VM rebuild without requiring manual configuration of the Kubernetes nodes.

Cilium has been installed using Ansible and Helm. The cluster has been validated with all nodes in the `Ready` state and CoreDNS running successfully.

The next implementation milestone is the GitOps platform, starting with Argo CD.