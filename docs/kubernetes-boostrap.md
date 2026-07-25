# Kubernetes Bootstrap

> **Status:** In progress  
> **Environment:** `test`  
> **Infrastructure provisioning:** Complete  
> **Current branch:** `feat/kubernetes-bootstrap`

## Purpose

This document describes how the Kubernetes cluster is bootstrapped on top of
the Proxmox virtual machines provisioned by OpenTofu, Terragrunt, and
Cloud-Init.

The bootstrap phase starts with three prepared Ubuntu virtual machines and ends
with a functioning Kubernetes cluster where:

- the control plane is initialized
- both worker nodes have joined
- all nodes report `Ready`
- containerd is used as the container runtime
- Cilium provides cluster networking
- CoreDNS and the Kubernetes system components are healthy
- the cluster can be accessed with `kubectl`

Application deployment and the GitOps platform are intentionally handled in a
later phase.

## Scope

This phase includes:

- Kubernetes node prerequisites
- containerd installation and configuration
- Kubernetes package installation
- kubeadm configuration
- control-plane initialization
- worker-node registration
- Cilium installation
- cluster health validation
- documentation of the rebuild procedure

This phase does not include:

- Argo CD
- OpenBao
- ingress controllers
- certificate management
- storage operators
- monitoring
- application workloads
- production-grade control-plane high availability

## Cluster topology

| Node | Role | Provisioning source |
|------|------|---------------------|
| `cpl-01` | Control plane | `infrastructure/live/test/proxmox/k8s/cpl-01/` |
| `wrk-01` | Worker | `infrastructure/live/test/proxmox/k8s/wrk-01/` |
| `wrk-02` | Worker | `infrastructure/live/test/proxmox/k8s/wrk-02/` |

The current environment contains one control-plane node.

This is appropriate for a learning and homelab environment, but it is not a
highly available control-plane design. If `cpl-01` is unavailable, the
Kubernetes API and the embedded etcd instance will also be unavailable.

## Technology decisions

| Area | Decision |
|------|----------|
| Cluster bootstrap | kubeadm |
| Container runtime | containerd |
| Container network interface | Cilium |
| Control-plane topology | Single control-plane node |
| Worker topology | Two worker nodes |
| kube-proxy | Enabled during the initial bootstrap |
| Kubernetes configuration | Version-controlled declarative configuration |
| Bootstrap secrets | Generated at runtime and never committed |
| GitOps platform | Added after cluster bootstrap |

### kube-proxy decision

The first cluster bootstrap will keep kube-proxy enabled.

Cilium will initially be installed as the CNI without replacing kube-proxy.
This reduces the number of moving parts during the first bootstrap.

Cilium kube-proxy replacement can be evaluated later as a separate,
intentional change.

## Repository boundaries

The repository has separate responsibilities for infrastructure provisioning
and Kubernetes configuration.

### `infrastructure/`

The `infrastructure/` directory owns:

- Proxmox virtual machines
- CPU, memory, and disk configuration
- network interfaces
- Cloud-Init configuration
- operating-system users
- SSH access
- infrastructure outputs

### `kubernetes/`

The `kubernetes/` directory owns:

- Kubernetes-specific host preparation
- containerd configuration
- Kubernetes package installation
- kubeadm configuration
- Cilium configuration
- bootstrap scripts
- cluster validation

Kubernetes bootstrap logic must not be added directly to the Proxmox module
unless it is a generic requirement that every provisioned VM should receive.

## Configuration values

The following values must be explicitly selected and documented before the
control plane is initialized.

| Setting | Value |
|---------|-------|
| Kubernetes minor version | `TBD` |
| containerd version or package source | `TBD` |
| Cilium chart version | `TBD` |
| Control-plane address | `TBD` |
| Control-plane endpoint | `TBD` |
| Kubernetes API port | `6443` |
| Service CIDR | `TBD` |
| Pod CIDR or Cilium IPAM configuration | `TBD` |
| Cluster DNS domain | `cluster.local` |
| Container runtime socket | `/run/containerd/containerd.sock` |

Versions must be pinned in the repository. Bootstrap scripts must not silently
install an unspecified latest version.

Network ranges must not overlap with:

- the Proxmox management network
- the home LAN
- VPN networks
- Docker networks used elsewhere in the homelab
- any existing routed private networks

## Bootstrap principles

The bootstrap implementation should follow these principles:

1. Commands should be repeatable where practical.
2. Configuration should be stored in Git.
3. Versions should be pinned.
4. Secrets and generated credentials must not be committed.
5. Scripts should fail immediately when a command fails.
6. Every stage should have an explicit validation step.
7. Manual commands should be documented.
8. The cluster should be rebuildable from the repository.

## Prerequisites

Before installing Kubernetes, confirm that:

- all three virtual machines are running
- SSH access works for all nodes
- each node has a unique hostname
- each node has a unique IP address
- all nodes can resolve each other's names or reach each other's IP addresses
- all nodes have synchronized system time
- outbound access to required package and image registries works
- the control-plane API port is reachable between nodes
- swap is disabled
- IPv4 forwarding is enabled
- the required Linux kernel functionality is available

### Initial connectivity checks

Run from the administration workstation:

```bash
ssh ubuntu@cpl-01
ssh ubuntu@wrk-01
ssh ubuntu@wrk-02