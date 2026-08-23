# Kubernetes Bootstrap

> **Status:** Complete
> **Environment:** `test`
> **Infrastructure provisioning:** Complete
> **Bootstrap validation:** Complete
> **Current branch:** `main`

## Purpose

This document describes how the Kubernetes cluster is bootstrapped on top of
the Proxmox virtual machines provisioned by OpenTofu, Terragrunt, and
Cloud-Init.

The bootstrap phase starts with three prepared Ubuntu virtual machines and ends with a functioning Kubernetes cluster where:

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
* [x] Kubernetes package installation
* [x] kubeadm control-plane initialization
* [x] Worker node join
* [x] Cilium installation
* [x] Cluster validation
* [x] Clean rebuild validation

## Configuration values

| Setting                    | Value                                    |
| -------------------------- | ---------------------------------------- |
| Kubernetes minor version   | `v1.36`                                  |
| Kubernetes package version | `1.36.4-1.1`                             |
| containerd package version | `2.2.1-0ubuntu1~24.04.3`                 |
| Cilium chart version       | `1.20.1`                                    |
| Control-plane address      | `192.168.10.170`                         |
| Control-plane endpoint     | `k8s-cpl-01.home:6443`                   |
| Kubernetes API port        | `6443`                                   |
| Service CIDR               | `10.96.0.0/12`                           |
| Pod CIDR                   | `10.244.0.0/16`                          |
| Cluster DNS domain         | `cluster.local`                          |
| Container runtime socket   | `unix:///run/containerd/containerd.sock` |

Versions are pinned in the repository to make cluster rebuilds deterministic.

## Stage 1: Prepare Kubernetes nodes

> **Status:** Complete

Kubernetes-specific operating-system preparation is automated with Ansible.

The `k8s_prereq` role:

```text
kubernetes/ansible/roles/k8s_prereq/
```

performs the following actions:

* disables swap
* disables persistent swap entries in `/etc/fstab`
* configures the `overlay` kernel module
* configures the `br_netfilter` kernel module
* loads required kernel modules
* enables bridge packet filtering
* enables IPv4 forwarding
* reloads sysctl configuration when required

### Validation

Verify required kernel modules:

```bash
ansible kubernetes -b -m shell \
  -a 'lsmod | grep -E "overlay|br_netfilter"'
```

Verify sysctl values:

```bash
ansible kubernetes -b -m shell \
  -a 'sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward'
```

Expected:

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Verify swap is disabled:

```bash
ansible kubernetes -b -m shell -a 'swapon --show'
```

Expected result: no output.

## Stage 2: Install and configure containerd

> **Status:** Complete

containerd is installed and configured through:

```text
kubernetes/ansible/roles/containerd/
```

The role:

* installs the pinned containerd package
* configures `/etc/containerd/config.toml`
* enables the `systemd` cgroup driver
* enables and starts the containerd service
* places the package on hold
* manages the configuration declaratively with Ansible

Current version:

```text
2.2.1-0ubuntu1~24.04.3
```

### Validation

Verify containerd version:

```bash
ansible kubernetes -b -m command -a 'containerd --version'
```

Verify the service:

```bash
ansible kubernetes -b -m command -a 'systemctl is-active containerd'
ansible kubernetes -b -m command -a 'systemctl is-enabled containerd'
```

Verify systemd cgroups:

```bash
ansible kubernetes -b -m shell \
  -a 'grep -n "SystemdCgroup" /etc/containerd/config.toml'
```

Expected:

```text
SystemdCgroup = true
```

Verify package hold:

```bash
ansible kubernetes -b -m shell \
  -a 'apt-mark showhold | grep "^containerd$"'
```

## Stage 3: Install Kubernetes packages

> **Status:** Complete

The Kubernetes package installation is automated using:

```text
kubernetes/ansible/roles/k8s_packages/
```

The role configures the official Kubernetes repository for the selected minor
release:

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```

The following packages are installed on all Kubernetes nodes:

* `kubelet`
* `kubeadm`
* `kubectl`

The selected versions are defined in:

```text
kubernetes/ansible/inventories/test/group_vars/kubernetes.yml
```

Current configuration:

```yaml
kubernetes_minor_version: "v1.36"
kubernetes_package_version: "1.36.4-1.1"
```

The same package version is used for `kubelet`, `kubeadm`, and `kubectl`.

The packages are held after installation to prevent unintended upgrades.

The `kubelet` service is enabled on all Kubernetes nodes.

### Validation

Verify kubeadm:

```bash
ansible kubernetes -b -m command -a 'kubeadm version'
```

Verify kubelet:

```bash
ansible kubernetes -b -m command -a 'kubelet --version'
```

Verify kubectl:

```bash
ansible kubernetes -b -m command -a 'kubectl version --client'
```

Expected Kubernetes version:

```text
v1.36.4
```

Verify package holds:

```bash
ansible kubernetes -b -m shell \
  -a 'apt-mark showhold | grep -E "^(kubelet|kubeadm|kubectl)$"'
```

Expected packages:

```text
kubeadm
kubectl
kubelet
```

The complete node preparation playbook has been executed repeatedly with:

```text
changed=0
failed=0
```

confirming that the current Ansible configuration is idempotent.

## Stage 4: Configure kubeadm

> **Status:** Complete

The kubeadm configuration is managed through:

```text
kubernetes/ansible/roles/kubeadm_control_plane/
```

The role renders:

```text
/etc/kubernetes/kubeadm-config.yaml
```

using a version-controlled Jinja2 template.

The configuration defines:

* Kubernetes version
* local API advertise address
* stable control-plane endpoint
* containerd CRI socket
* service CIDR
* pod CIDR
* cluster DNS domain

The generated configuration is validated before initialization:

```bash
kubeadm config validate \
  --config /etc/kubernetes/kubeadm-config.yaml
```

Expected:

```text
ok
```

## Stage 5: Initialize the control plane

> **Status:** Complete

The control plane node is:

```text
k8s-cpl-01
```

The Ansible role initializes the control plane using:

```bash
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
```

The initialization is idempotent.

Before running `kubeadm init`, the role checks for:

```text
/etc/kubernetes/admin.conf
```

If the file already exists, initialization is skipped.

The administrative kubeconfig is copied to the configured administrator user:

```text
/home/ubuntu/.kube/config
```

with restrictive file permissions.

### Current control-plane state

```text
Kubernetes version:    v1.36.4
Node:                  k8s-cpl-01
Internal IP:           192.168.10.170
API endpoint:          k8s-cpl-01.home:6443
Container runtime:     containerd 2.2.1
```

### Validation

Verify the node:

```bash
kubectl get nodes -o wide
```

Expected result immediately after kubeadm initialization:

```text
k8s-cpl-01   NotReady   control-plane
```

Verify system components:

```bash
kubectl get pods -n kube-system -o wide
```

The following components are currently running:

* etcd
* kube-apiserver
* kube-controller-manager
* kube-scheduler
* kube-proxy

CoreDNS remains `Pending` until cluster networking is installed.

The `NotReady` control-plane state is expected until Cilium is available.


## Stage 6: Join worker nodes

> **Status:** Complete

The worker nodes are joined to the cluster automatically with Ansible.

The worker role is located at:

```text
kubernetes/ansible/roles/kubeadm_worker/
````

The control plane generates a short-lived kubeadm join command using:

```bash
kubeadm token create --print-join-command
```

The generated command is stored only in Ansible runtime memory and is not written to Git or a persistent file.

The worker role checks for:

```text
/etc/kubernetes/kubelet.conf
```

before attempting to join a node. If the file already exists, the worker is considered joined and `kubeadm join` is skipped.

The following nodes have joined the cluster:

* `k8s-wrk-01`
* `k8s-wrk-02`

### Validation

Verify cluster membership from the control plane:

```bash
kubectl get nodes -o wide
```

At this stage, before Cilium is installed, the expected state is:

```text
k8s-cpl-01   NotReady   control-plane
k8s-wrk-01   NotReady   <none>
k8s-wrk-02   NotReady   <none>
```

All three nodes are registered with the Kubernetes API.

The `NotReady` state is expected until the cluster CNI is installed.

## Definition of done

The Kubernetes bootstrap phase is complete when:

* [x] Kubernetes node prerequisites are automated with Ansible
* [x] Swap is disabled
* [x] Required kernel modules are configured
* [x] Required sysctl values are configured
* [x] containerd is installed and configured on every node
* [x] containerd uses `SystemdCgroup = true`
* [x] containerd package version is explicitly pinned
* [x] Kubernetes package versions are explicitly pinned
* [x] `kubelet`, `kubeadm`, and `kubectl` are installed on every node
* [x] Kubernetes packages are held against unintended upgrades
* [x] kubeadm configuration is generated and validated
* [x] `k8s-cpl-01` is initialized with kubeadm
* [x] Administrative kubeconfig is configured
* [x] Kubernetes control-plane components are running
* [x] `k8s-wrk-01` has joined the cluster
* [x] `k8s-wrk-02` has joined the cluster
* [x] Cilium is installed with a pinned version
* [ ] All three nodes report `Ready`
* [ ] CoreDNS is healthy
* [ ] Cilium reports a healthy status
* [ ] Cilium connectivity tests pass
* [ ] Kubernetes API readiness checks pass
* [ ] No bootstrap credentials are stored in Git
* [ ] The bootstrap process has been tested after a clean rebuild
* [ ] Repository documentation reflects the completed implementation

## Stage 7: Install Cilium

> **Status:** Complete

Cluster networking is provided by Cilium.

Cilium is installed automatically after the Kubernetes bootstrap using the
Ansible playbook:

```text
kubernetes/ansible/playbooks/install-cilium.yml
```

The playbook executes the Ansible role:

```text
kubernetes/ansible/roles/cilium/
```

The role performs the following actions:

* Adds the official Cilium Helm repository.
* Installs or upgrades the pinned Cilium Helm chart.
* Waits for the Cilium DaemonSet rollout.
* Waits for the Cilium operator rollout.
* Waits for all Kubernetes nodes to become `Ready`.
* Verifies CoreDNS health.
* Restarts CoreDNS only if required.
* Waits for CoreDNS to become healthy.

The current implementation intentionally keeps kube-proxy enabled.

### Validation

Verify node readiness:

```bash
kubectl get nodes -o wide
```

Validated result:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

Verify Cilium:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

Verify the operator:

```bash
kubectl -n kube-system get deployment cilium-operator
```

Verify CoreDNS:

```bash
kubectl -n kube-system get deployment coredns
```

## Stage 8: Validate the cluster

> **Status:** Complete

The Kubernetes bootstrap has been validated after a complete infrastructure
rebuild using the following workflow:

```text
Terragrunt destroy
        ↓
Terragrunt apply
        ↓
bootstrap-k8s.sh
        ↓
Kubernetes Ready
```

### Node validation

```bash
kubectl get nodes -o wide
```

Validated result:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

### System workloads

```bash
kubectl get pods -A -o wide
```

Validated components:

* etcd
* kube-apiserver
* kube-controller-manager
* kube-scheduler
* kube-proxy
* CoreDNS
* Cilium
* Cilium Operator

### API readiness

```bash
kubectl get --raw='/readyz?verbose'
```

### DNS

CoreDNS is healthy and cluster DNS is operational.

### Networking

Cluster networking is provided by Cilium.

Node-to-node communication has been validated.

Future work includes running the full Cilium connectivity test.

## Definition of done

The Kubernetes bootstrap phase is complete when:

* [x] Kubernetes node prerequisites are automated with Ansible
* [x] Swap is disabled
* [x] Required kernel modules are configured
* [x] Required sysctl values are configured
* [x] containerd is installed and configured on every node
* [x] containerd uses `SystemdCgroup = true`
* [x] containerd package version is explicitly pinned
* [x] Kubernetes package versions are explicitly pinned
* [x] `kubelet`, `kubeadm`, and `kubectl` are installed on every node
* [x] Kubernetes packages are held against unintended upgrades
* [x] kubeadm configuration is generated and validated
* [x] `k8s-cpl-01` is initialized with kubeadm
* [x] Administrative kubeconfig is configured
* [x] Kubernetes control-plane components are running
* [x] `k8s-wrk-01` has joined the cluster
* [x] `k8s-wrk-02` has joined the cluster
* [x] Local kubeconfig is refreshed after cluster rebuild
* [x] Cilium is installed with a pinned version
* [x] All Kubernetes nodes report `Ready`
* [x] CoreDNS is healthy
* [ ] Cilium connectivity tests pass
* [x] Kubernetes API readiness checks pass
* [x] No bootstrap credentials are stored in Git
* [x] The bootstrap process has been tested after a clean rebuild
* [x] Repository documentation reflects the completed implementation

## Next phase

The Kubernetes bootstrap phase is complete.

The next implementation milestone is the GitOps platform.

Planned work includes:

* Argo CD
* Git reconciliation
* OpenBao
* Platform services
* Application deployment
