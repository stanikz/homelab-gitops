# Homelab GitOps

A GitOps-driven homelab built with OpenTofu, Terragrunt, Proxmox and Kubernetes.

The purpose of this repository is to learn, experiment and build a production-inspired Kubernetes platform using Infrastructure as Code (IaC) and GitOps principles.

---

# Architecture

```
                Git Repository
                      │
                      ▼
                OpenTofu Modules
                      │
                      ▼
                 Terragrunt
                      │
                      ▼
                 Proxmox VE
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

---

# Technology Stack

| Component | Technology |
|----------|------------|
| Infrastructure as Code | OpenTofu |
| Orchestration | Terragrunt |
| Hypervisor | Proxmox VE |
| Operating System | Ubuntu Server 24.04 LTS |
| Provisioning | Cloud-Init |
| Kubernetes | kubeadm |
| Container Runtime | containerd |
| GitOps | Argo CD *(planned)* |
| Networking | Cilium *(planned)* |
| Secrets Management | OpenBao *(planned)* |

---

# Repository Structure

```text
homelab-gitops/
├── apps/                    # Applications managed by ArgoCD
│
├── infrastructure/
│   ├── live/                # Terragrunt environments
│   └── modules/             # Reusable OpenTofu modules
│
├── k8s/                     # Kubernetes bootstrap
│
└── platform/                # Platform services (OpenBao, ArgoCD, etc.)
```

---

# Requirements

Install the following software before using this repository.

- Git
- OpenTofu
- Terragrunt
- OpenSSH

---

# Authentication

Provisioning requires two different authentication mechanisms.

## Proxmox API

OpenTofu authenticates against the Proxmox API using an API Token.

Required environment variables:

```bash
export PROXMOX_VE_ENDPOINT="https://pve.example.com:8006/api2/json"
export PROXMOX_VE_API_TOKEN="user@realm!terraform=xxxxxxxx-xxxx-xxxx-xxxx"
```

---

## SSH

Cloud-Init snippets are uploaded over SSH to the Proxmox node.

Verify that an SSH agent is running:

```bash
echo $SSH_AUTH_SOCK
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

---

# Quick Start

## Clone the repository

```bash
git clone <repository-url>
cd homelab-gitops
```

## Export environment variables

```bash
export PROXMOX_VE_ENDPOINT="https://pve.example.com:8006/api2/json"
export PROXMOX_VE_API_TOKEN="user@realm!terraform=xxxxxxxx-xxxx-xxxx-xxxx"
```

## Load your SSH key

```bash
ssh-add ~/.ssh/id_ed25519
```

## Review the infrastructure

```bash
cd infrastructure/live/test/proxmox/k8s

terragrunt run --all plan
```

## Deploy

```bash
terragrunt run --all apply
```

## Destroy

```bash
terragrunt run --all destroy
```

---

# Current Features

- Reusable OpenTofu module for Proxmox VMs
- Terragrunt-managed environments
- Ubuntu template cloning
- Cloud-Init provisioning
- Static IP configuration
- SSH key injection
- Password hash support
- QEMU Guest Agent enabled
- Configurable CPU, memory and storage
- Parameterized VM configuration

---

# Roadmap

## Stage 1

- [x] Repository structure
- [x] OpenTofu module
- [x] Terragrunt
- [x] Proxmox VM provisioning
- [x] Cloud-Init

## Stage 2

- [ ] Kubernetes bootstrap
- [ ] kubeadm init
- [ ] Worker node join
- [ ] containerd configuration

## Stage 3

- [ ] Cilium
- [ ] Argo CD
- [ ] OpenBao

## Stage 4

- [ ] Monitoring
- [ ] Logging
- [ ] GitOps applications
- [ ] Automated upgrades

---

# Notes

Cloud-Init configuration is generated dynamically from templates inside the reusable OpenTofu module.

Sensitive information such as passwords, API tokens and SSH keys are **never** stored directly in the module and should instead be provided through environment variables or external variable files.