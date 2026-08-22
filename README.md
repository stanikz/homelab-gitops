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
| Networking | Cilium *(planned)* |
| GitOps | Argo CD *(planned)* |
| Secrets Management | OpenBao *(planned)* |

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
└── scripts/                 # Local automation and helper scripts
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

Apply the Kubernetes bootstrap:

```bash
ansible-playbook playbooks/prepare-nodes.yml
```

The playbook prepares all Kubernetes nodes, installs and configures containerd,
installs pinned Kubernetes packages, initializes the control plane and joins
the worker nodes to the cluster.

## Destroy the infrastructure

Return to the repository root and run:

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
* Common node troubleshooting utilities

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

Cluster networking is not yet configured. Until Cilium is installed, the nodes
are expected to remain in the `NotReady` state.

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
* [ ] Cilium
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

---

# Security

Sensitive information such as passwords, API tokens, backend credentials,
kubeadm join credentials and SSH private keys must never be committed to Git.

Backend credentials are retrieved from Bitwarden at runtime.

kubeadm worker join credentials are generated dynamically during the Ansible
bootstrap and are only used during execution.

---

# Notes

Cloud-Init configuration is generated dynamically from templates inside the
reusable OpenTofu module.

OpenTofu state is stored remotely in RustFS rather than inside the local
Terragrunt cache.

The current Kubernetes cluster has completed the kubeadm bootstrap stage. The
next milestone is installing Cilium and validating cluster networking, CoreDNS and node readiness.