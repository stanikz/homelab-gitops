# Kubernetes

This directory contains the Ansible automation used to bootstrap the homelab
Kubernetes cluster.

The virtual machines themselves are provisioned separately by the OpenTofu and
Terragrunt configuration under:

```text
infrastructure/
```

## Cluster

| Node | Role |
|------|------|
| `k8s-cpl-01` | Control Plane |
| `k8s-wrk-01` | Worker |
| `k8s-wrk-02` | Worker |

## Bootstrap Workflow

The Kubernetes bootstrap is fully automated through:

```bash
./scripts/bootstrap-k8s.sh
```

The bootstrap performs the following phases:

1. Refresh Kubernetes SSH host keys.
2. Verify Ansible connectivity.
3. Prepare Kubernetes nodes.
4. Install and configure containerd.
5. Install pinned Kubernetes packages.
6. Initialize the kubeadm control plane.
7. Join worker nodes.
8. Refresh the local kubeconfig.
9. Install Cilium.
10. Validate node readiness and CoreDNS.

## Structure

```text
ansible/
├── inventories/
├── playbooks/
│   ├── prepare-nodes.yml
│   └── install-cilium.yml
└── roles/
    ├── k8s_prereq/
    ├── containerd/
    ├── k8s_packages/
    ├── kubeadm_control_plane/
    ├── kubeadm_worker/
    └── cilium/
```

## Documentation

Additional documentation is available in:

* `docs/kubernetes-bootstrap.md`
* `docs/cilium.md`

## Status

Stage 2 — Kubernetes Bootstrap has been completed successfully.

The next phase is implementing the GitOps platform with Argo CD.