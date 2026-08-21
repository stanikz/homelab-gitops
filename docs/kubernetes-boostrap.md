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

* the control plane is initialized
* both worker nodes have joined
* all nodes report `Ready`
* containerd is used as the container runtime
* Cilium provides cluster networking
* CoreDNS and the Kubernetes system components are healthy
* the cluster can be accessed with `kubectl`

Application deployment and the GitOps platform are intentionally handled in a
later phase.

## Bootstrap progress

* [x] Proxmox VM provisioning
* [x] Cloud-Init baseline
* [x] DNS configuration
* [x] Ansible connectivity
* [x] Kubernetes node prerequisites
* [x] containerd installation and configuration
* [ ] Kubernetes package installation
* [ ] kubeadm control-plane initialization
* [ ] Worker node join
* [ ] Cilium installation
* [ ] Cluster validation

## Scope

This phase includes:

* Kubernetes node prerequisites
* containerd installation and configuration
* Kubernetes package installation
* kubeadm configuration
* control-plane initialization
* worker-node registration
* Cilium installation
* cluster health validation
* documentation of the rebuild procedure

This phase does not include:

* Argo CD
* OpenBao
* ingress controllers
* certificate management
* storage operators
* monitoring
* application workloads
* production-grade control-plane high availability

## Cluster topology

| Node         | Role          | Provisioning source                            |
| ------------ | ------------- | ---------------------------------------------- |
| `k8s-cpl-01` | Control plane | `infrastructure/live/test/proxmox/k8s/cpl-01/` |
| `k8s-wrk-01` | Worker        | `infrastructure/live/test/proxmox/k8s/wrk-01/` |
| `k8s-wrk-02` | Worker        | `infrastructure/live/test/proxmox/k8s/wrk-02/` |

The current environment contains one control-plane node.

This is appropriate for a learning and homelab environment, but it is not a
highly available control-plane design. If `k8s-cpl-01` is unavailable, the
Kubernetes API and the embedded etcd instance will also be unavailable.

## Technology decisions

| Area                        | Decision                                     |
| --------------------------- | -------------------------------------------- |
| Cluster bootstrap           | kubeadm                                      |
| Configuration management    | Ansible                                      |
| Container runtime           | containerd                                   |
| Container network interface | Cilium                                       |
| Control-plane topology      | Single control-plane node                    |
| Worker topology             | Two worker nodes                             |
| kube-proxy                  | Enabled during the initial bootstrap         |
| Kubernetes configuration    | Version-controlled declarative configuration |
| Bootstrap secrets           | Generated at runtime and never committed     |
| GitOps platform             | Added after cluster bootstrap                |

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

* Proxmox virtual machines
* CPU, memory, and disk configuration
* network interfaces
* Cloud-Init configuration
* operating-system users
* SSH access
* infrastructure outputs

### `kubernetes/`

The `kubernetes/` directory owns:

* Kubernetes-specific host preparation
* Ansible inventories, playbooks, and roles
* containerd configuration
* Kubernetes package installation
* kubeadm configuration
* Cilium configuration
* cluster validation

Host configuration is automated with Ansible. Cloud-Init provides the generic
Ubuntu baseline, while Ansible owns Kubernetes-specific operating-system
configuration.

Kubernetes bootstrap logic must not be added directly to the Proxmox module
unless it is a generic requirement that every provisioned VM should receive.

## Configuration values

The following values must be explicitly selected and documented before the
control plane is initialized.

| Setting                               | Value                             |
| ------------------------------------- | --------------------------------- |
| Kubernetes minor version              | `TBD`                             |
| containerd version or package source  | `2.2.1-0ubuntu1~24.04.3`          |
| Cilium chart version                  | `TBD`                             |
| Control-plane address                 | `TBD`                             |
| Control-plane endpoint                | `TBD`                             |
| Kubernetes API port                   | `6443`                            |
| Service CIDR                          | `TBD`                             |
| Pod CIDR or Cilium IPAM configuration | `TBD`                             |
| Cluster DNS domain                    | `cluster.local`                   |
| Container runtime socket              | `/run/containerd/containerd.sock` |

Versions must be pinned in the repository. Automation must not silently install
an unspecified latest version.

Network ranges must not overlap with:

* the Proxmox management network
* the home LAN
* VPN networks
* Docker networks used elsewhere in the homelab
* any existing routed private networks

## Bootstrap principles

The bootstrap implementation should follow these principles:

1. Commands and playbooks should be repeatable where practical.
2. Configuration should be stored in Git.
3. Versions should be pinned.
4. Secrets and generated credentials must not be committed.
5. Ansible roles should be idempotent and safe to run repeatedly.
6. Every stage should have an explicit validation step.
7. Manual commands should be documented.
8. The cluster should be rebuildable from the repository.
9. Kubernetes-specific host configuration should not be duplicated in Cloud-Init.

## Ansible automation

Kubernetes node configuration is automated using Ansible.

The current structure is:

```text
kubernetes/ansible/
├── ansible.cfg
├── inventories/
│   └── test/
│       └── hosts.yml
├── playbooks/
│   └── prepare-nodes.yml
└── roles/
    └── k8s_prereq/
        ├── handlers/
        │   └── main.yml
        └── tasks/
            └── main.yml
```

The inventory defines the following groups:

* `control_plane`
* `workers`
* `kubernetes`

The `kubernetes` group contains all cluster nodes.

### Connectivity validation

From the repository root:

```bash
cd kubernetes/ansible
```

Verify Ansible connectivity:

```bash
ansible kubernetes -m ping
```

Verify privilege escalation:

```bash
ansible kubernetes -b -m command -a "whoami"
```

Expected result for each node:

```text
root
```

## Prerequisites

Before installing Kubernetes, confirm that:

* all three virtual machines are running
* SSH access works for all nodes
* each node has a unique hostname
* each node has a unique IP address
* all nodes can resolve each other's names
* all nodes have synchronized system time
* outbound access to required package and image registries works
* the control-plane API port is reachable between nodes
* swap is disabled
* IPv4 forwarding is enabled
* the required Linux kernel functionality is available

### Initial connectivity checks

Run from the administration workstation:

```bash
ssh ubuntu@k8s-cpl-01.home.arpa
ssh ubuntu@k8s-wrk-01.home.arpa
ssh ubuntu@k8s-wrk-02.home.arpa
```

Verify DNS resolution:

```bash
getent hosts k8s-cpl-01
getent hosts k8s-wrk-01
getent hosts k8s-wrk-02
```

Verify basic network connectivity:

```bash
ping -c 3 k8s-cpl-01
ping -c 3 k8s-wrk-01
ping -c 3 k8s-wrk-02
```

## Stage 1: Prepare Kubernetes nodes

> **Status:** Complete

The first Ansible role prepares all Kubernetes nodes with the operating-system
settings required by Kubernetes.

The role is located at:

```text
kubernetes/ansible/roles/k8s_prereq/
```

The role performs the following actions:

* disables swap
* disables persistent swap entries in `/etc/fstab`
* configures the `overlay` kernel module
* configures the `br_netfilter` kernel module
* loads the required kernel modules
* enables bridge packet filtering
* enables IPv4 forwarding
* reloads sysctl configuration when required

The playbook is located at:

```text
kubernetes/ansible/playbooks/prepare-nodes.yml
```

### Dry-run

Run a dry-run before applying changes:

```bash
cd kubernetes/ansible

ansible-playbook playbooks/prepare-nodes.yml --check --diff
```

### Apply

Apply the node preparation configuration:

```bash
ansible-playbook playbooks/prepare-nodes.yml
```

### Validation

Verify that the required kernel modules are loaded:

```bash
ansible kubernetes -b -m shell \
  -a 'lsmod | grep -E "overlay|br_netfilter"'
```

Expected modules:

```text
overlay
br_netfilter
```

Verify the required sysctl settings:

```bash
ansible kubernetes -b -m shell \
  -a 'sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward'
```

Expected values:

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Verify that swap is disabled:

```bash
ansible kubernetes -b -m shell -a 'swapon --show'
```

Expected result:

```text
No output
```

All three nodes have passed the node preparation validation checks.

## Stage 2: Install and configure containerd

> **Status:** Complete

containerd will be installed and configured on all Kubernetes nodes using
Ansible.

The containerd configuration must:

* enable the Container Runtime Interface
* use the systemd cgroup driver
* start automatically at boot
* use `/run/containerd/containerd.sock`
* use a version or package source explicitly defined by the repository

The planned Ansible role is:

```text
kubernetes/ansible/roles/containerd/
```

### Validation

The stage will be considered complete when the following checks succeed on all
nodes:

```bash
systemctl is-active containerd
systemctl is-enabled containerd
containerd --version
```

CRI connectivity will also be validated before kubeadm is installed.

## Stage 3: Install Kubernetes packages

> **Status:** Not started

The following components will be installed on all Kubernetes nodes:

* `kubelet`
* `kubeadm`
* `kubectl`

All packages must use the same selected Kubernetes minor version.

Package versions will be pinned so a normal operating-system upgrade cannot
unexpectedly upgrade the Kubernetes cluster.

### Validation

The stage will be considered complete when:

```bash
kubeadm version
kubelet --version
kubectl version --client
```

report the expected Kubernetes version on all nodes.

## Stage 4: Configure kubeadm

> **Status:** Not started

The control plane should be initialized using a version-controlled kubeadm
configuration file rather than a long command containing multiple flags.

The planned location is:

```text
kubernetes/ansible/
```

or a dedicated Kubernetes bootstrap configuration directory introduced when
the kubeadm implementation is created.

The configuration must explicitly define:

* Kubernetes version
* control-plane endpoint
* API advertise address
* container runtime socket
* service CIDR
* pod networking configuration
* cluster DNS domain

Generated credentials and bootstrap tokens must never be committed.

## Stage 5: Initialize the control plane

> **Status:** Not started

The control plane will be initialized on:

```text
k8s-cpl-01
```

using `kubeadm init`.

After initialization:

* the Kubernetes API must be reachable
* administrative kubeconfig access must be configured
* the control-plane components must be healthy
* a worker join command must be generated

The worker join token must not be committed to Git.

## Stage 6: Join worker nodes

> **Status:** Not started

The following worker nodes will join the cluster:

```text
k8s-wrk-01
k8s-wrk-02
```

Worker registration will be performed using `kubeadm join`.

After both workers have joined:

```bash
kubectl get nodes -o wide
```

should list all three nodes.

Nodes may remain `NotReady` until the CNI has been installed.

## Stage 7: Install Cilium

> **Status:** Not started

Cilium will provide the Kubernetes Container Network Interface.

For the initial bootstrap:

* kube-proxy will remain enabled
* the Cilium version will be pinned
* configuration will be stored in Git
* generated secrets will not be committed

After installation, validate:

```bash
kubectl get pods -n kube-system
kubectl get nodes -o wide
cilium status --wait
```

A Cilium connectivity test should also be performed:

```bash
cilium connectivity test
```

## Stage 8: Validate the cluster

> **Status:** Not started

The Kubernetes bootstrap is complete only after the entire cluster has been
validated.

### Node health

```bash
kubectl get nodes -o wide
```

Expected result:

* `k8s-cpl-01` is `Ready`
* `k8s-wrk-01` is `Ready`
* `k8s-wrk-02` is `Ready`

### System workloads

```bash
kubectl get pods -A -o wide
```

Expected healthy components include:

* Kubernetes API server
* controller manager
* scheduler
* etcd
* CoreDNS
* kube-proxy
* Cilium

### API health

```bash
kubectl get --raw='/readyz?verbose'
```

The required API server readiness checks should pass.

### DNS

Cluster DNS must successfully resolve:

```text
kubernetes.default.svc.cluster.local
```

### Networking

Cross-node pod networking must work between workloads running on different
worker nodes.

Cilium's connectivity test will be used as the primary network validation.

## Secret handling

The following values and files must never be committed:

* `/etc/kubernetes/admin.conf`
* copied administrator kubeconfig files
* kubeadm join commands
* kubeadm bootstrap tokens
* certificate keys
* private certificate material
* service-account private keys

Relevant local files should be ignored through `.gitignore` where necessary.

Examples:

```gitignore
kubeconfig
*.kubeconfig
admin.conf
join-command.sh
bootstrap-token*
certificate-key*
```

## Failure and rebuild strategy

The environment is designed to be reproducible.

During the initial development phase, rebuilding a failed node is preferred
over accumulating undocumented manual fixes.

The general recovery process is:

1. Save useful non-secret diagnostic output.
2. Determine whether the failure belongs to infrastructure or Kubernetes.
3. Fix the declarative configuration.
4. Reprovision or reset the affected node.
5. Re-run the documented automation.
6. Validate the node and cluster again.

For a completely clean rebuild, the Proxmox VMs can be destroyed and recreated
through Terragrunt.

Infrastructure state remains stored remotely in RustFS and is independent of
the local `.terragrunt-cache` directories.

## Definition of done

The Kubernetes bootstrap phase is complete when:

* [x] Kubernetes node prerequisites are automated with Ansible
* [x] Swap is disabled
* [x] Required kernel modules are configured
* [x] Required sysctl values are configured
* [ ] containerd is installed and configured on every node
* [ ] Kubernetes package versions are explicitly pinned
* [ ] `k8s-cpl-01` is initialized with kubeadm
* [ ] `k8s-wrk-01` has joined the cluster
* [ ] `k8s-wrk-02` has joined the cluster
* [ ] Cilium is installed with a pinned version
* [ ] All three nodes report `Ready`
* [ ] CoreDNS is healthy
* [ ] Cilium reports a healthy status
* [ ] Cilium connectivity tests pass
* [ ] Kubernetes API readiness checks pass
* [ ] No bootstrap credentials are stored in Git
* [ ] The bootstrap process has been tested after a clean rebuild
* [ ] Repository documentation reflects the completed implementation

## Next phase

After the Kubernetes bootstrap definition of done has been met, the cluster
will become the foundation for the GitOps platform.

The next planned work will introduce:

* Argo CD
* Git reconciliation
* platform services
* OpenBao
* application deployment
