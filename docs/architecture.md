# Architecture

The overall deployment flow is illustrated below.

```text
                 Git Repository
                       │
                       ▼
                 OpenTofu Modules
                       │
                       ▼
                  Terragrunt
                       │
                       ▼
                  Proxmox API
                       │
                       ▼
              Ubuntu VM Template
                       │
                       ▼
                  Cloud-Init
                       │
                       ▼
                  Kubernetes
                    kubeadm
                       │
                       ▼
                    Cilium
                       │
                       ▼
                    Argo CD
                       │
                       ▼
          Platform Services & Applications
```

## Infrastructure Flow

1. Terragrunt loads shared configuration.
2. OpenTofu provisions virtual machines.
3. Proxmox clones an Ubuntu template.
4. Cloud-Init customizes each VM.
5. Kubernetes is bootstrapped using kubeadm.
6. Argo CD deploys the remaining platform.