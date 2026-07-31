# Kubernetes

This directory contains the Kubernetes cluster bootstrap configuration, scripts, and manifests for the homelab.

The virtual machines are provisioned separately under [`infrastructure/`](../infrastructure/).

## Cluster

| Node | Role |
|------|------|
| `cpl-01` | Control plane |
| `wrk-01` | Worker |
| `wrk-02` | Worker |

## Bootstrap stages

1. Prepare the operating system
2. Install and configure containerd
3. Install Kubernetes packages
4. Initialize the control plane with kubeadm
5. Join the worker nodes
6. Install Cilium
7. Validate the cluster

See [`docs/kubernetes-bootstrap.md`](../docs/kubernetes-bootstrap.md) for the complete bootstrap procedure.

## Status

Kubernetes bootstrap is currently in progress.