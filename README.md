# Homelab GitOps

A GitOps-driven homelab built with OpenTofu, Terragrunt, Proxmox and Kubernetes.

The purpose of this repository is to learn, experiment and build a
production-inspired Kubernetes platform using Infrastructure as Code (IaC) and
GitOps principles.

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
             Kubernetes
              (kubeadm)
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

Backend credentials are retrieved from Bitwarden at runtime and are not stored
in the repository.

---

# Technology Stack

| Component              | Technology              |
| ---------------------- | ----------------------- |
| Infrastructure as Code | OpenTofu                |
| Orchestration          | Terragrunt              |
| Hypervisor             | Proxmox VE              |
| Operating System       | Ubuntu Server 24.04 LTS |
| Provisioning           | Cloud-Init              |
| Remote State           | RustFS                  |
| Credential Management  | Bitwarden CLI           |
| Kubernetes             | kubeadm                 |
| Container Runtime      | containerd              |
| Networking             | Cilium *(planned)*      |
| GitOps                 | Argo CD *(planned)*     |
| Secrets Management     | OpenBao *(planned)*     |

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
├── kubernetes/              # Kubernetes bootstrap and cluster configuration
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

## Deploy:

```bash
./scripts/terragrunt-bw.sh run --all apply \
  --working-dir infrastructure/live/test
```

## Destroy:

```bash
./scripts/terragrunt-bw.sh run --all destroy \
  --working-dir infrastructure/live/test
```

---

# Current Features

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
* RustFS S3-compatible remote state
* S3 state locking
* Bitwarden-backed backend authentication
* OpenTofu dependency lock files tracked in Git
* Common node troubleshooting utilities

---

# Roadmap

## Stage 1

* [x] Repository structure
* [x] OpenTofu module
* [x] Terragrunt
* [x] Proxmox VM provisioning
* [x] Cloud-Init
* [x] Remote state backend
* [x] Backend credential management

## Stage 2

* [ ] Kubernetes node preparation
* [ ] containerd configuration
* [ ] Kubernetes package installation
* [ ] kubeadm control-plane bootstrap
* [ ] Worker node join

## Stage 3

* [ ] Cilium
* [ ] Argo CD
* [ ] OpenBao

## Stage 4

* [ ] Monitoring
* [ ] Logging
* [ ] GitOps applications
* [ ] Automated upgrades

---

# Notes

Cloud-Init configuration is generated dynamically from templates inside the
reusable OpenTofu module.

OpenTofu state is stored remotely in RustFS rather than inside the local
Terragrunt cache.

Sensitive information such as passwords, API tokens, backend credentials and
SSH private keys are never stored directly in the module and should instead be
provided through environment variables or external secret-management systems.

`.terraform.lock.hcl` files are intentionally committed to Git to keep provider
versions and checksums reproducible.
