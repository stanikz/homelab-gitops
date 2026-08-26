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
│       Architecture and per-component documentation.
│
├── infrastructure/
│       Infrastructure provisioning (OpenTofu + Terragrunt).
│   ├── live/
│   │       Terragrunt environments.
│   └── modules/
│           Reusable OpenTofu modules.
│
├── kubernetes/
│       Kubernetes bootstrap (Ansible + kubeadm + Cilium).
│   └── ansible/
│       ├── inventories/
│       ├── playbooks/
│       └── roles/
│               argocd, cert_manager, cilium, containerd,
│               k8s_prereq, k8s_packages,
│               kubeadm_control_plane, kubeadm_worker
│
├── gitops/
│       GitOps content reconciled by Argo CD.
│   ├── bootstrap/
│   │       app-of-apps root Application.
│   └── platform/
│           Argo CD-managed platform resources.
│       ├── argocd/       Argo CD HTTPRoute.
│       ├── gateway/      Shared Cilium Gateway (HTTP/HTTPS) + namespace.
│       └── networking/   Cilium LB-IPAM pool + L2 announcement policy.
│
└── scripts/
        bootstrap-k8s.sh, refresh-k8s-known-hosts.sh, terragrunt-bw.sh
```