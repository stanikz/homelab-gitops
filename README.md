# homelab-gitops
homelab gitops repo for learning purposes

## Repo structure

```
homelab-gitops/
├── infrastructure/   # OpenTofu + Terragrunt
├── cloud-init/       # Ubuntu cloud-init templates
├── kubernetes/       # kubeadm bootstrap
├── platform/         # ArgoCD bootstrap + OpenBao
└── applications/     # Everything deployed by ArgoCD
```

## Requirements
Ensure the following tools are installed before running this repository:

```
* Git
* OpenTofu
* Terragrunt (Open source version of Terraform)
```