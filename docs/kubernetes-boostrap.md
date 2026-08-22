## Bootstrap progress

Replace the current progress section with:

```md
## Bootstrap progress

- [x] Proxmox VM provisioning
- [x] Cloud-Init baseline
- [x] DNS configuration
- [x] Ansible connectivity
- [x] Kubernetes node prerequisites
- [x] containerd installation and configuration
- [x] Kubernetes package installation
- [ ] kubeadm control-plane initialization
- [ ] Worker node join
- [ ] Cilium installation
- [ ] Cluster validation
```

## Configuration values

Update the Kubernetes version rows to:

```md
| Setting | Value |
|---------|-------|
| Kubernetes minor version | `v1.36` |
| Kubernetes package version | `1.36.4-1.1` |
| containerd version or package source | `2.2.1-0ubuntu1~24.04.3` |
| Cilium chart version | `TBD` |
| Control-plane address | `TBD` |
| Control-plane endpoint | `TBD` |
| Kubernetes API port | `6443` |
| Service CIDR | `TBD` |
| Pod CIDR or Cilium IPAM configuration | `TBD` |
| Cluster DNS domain | `cluster.local` |
| Container runtime socket | `/run/containerd/containerd.sock` |
```

## Stage 3: Install Kubernetes packages

Replace the current Stage 3 section with:

````md
## Stage 3: Install Kubernetes packages

> **Status:** Complete

The Kubernetes package installation is automated using the Ansible role:

```text
kubernetes/ansible/roles/k8s_packages/
````

The role configures the official Kubernetes package repository for the selected
minor release:

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```

The following packages are installed on all Kubernetes nodes:

* `kubelet`
* `kubeadm`
* `kubectl`

The exact package version is pinned through:

```text
kubernetes/ansible/inventories/test/group_vars/kubernetes.yml
```

Current configuration:

```yaml
kubernetes_minor_version: "v1.36"
kubernetes_package_version: "1.36.4-1.1"
```

The same package version is used for `kubelet`, `kubeadm`, and `kubectl` to
keep the Kubernetes toolchain consistent across all nodes.

The packages are placed on hold after installation to prevent unintended
upgrades during normal operating-system package updates.

The `kubelet` service is enabled on all nodes.

At this stage, the kubelet may not yet be fully operational because the nodes
have not been initialized or joined with kubeadm.

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

All nodes should report Kubernetes version:

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

The complete node preparation playbook has also been executed a second time
successfully with:

```text
changed=0
failed=0
```

confirming that the current Ansible configuration is idempotent.

````

## Definition of done

Update the beginning of the checklist to:

```md
## Definition of done

The Kubernetes bootstrap phase is complete when:

- [x] Kubernetes node prerequisites are automated with Ansible
- [x] Swap is disabled
- [x] Required kernel modules are configured
- [x] Required sysctl values are configured
- [x] containerd is installed and configured on every node
- [x] containerd uses `SystemdCgroup = true`
- [x] containerd package version is explicitly pinned
- [x] Kubernetes package versions are explicitly pinned
- [x] `kubelet`, `kubeadm`, and `kubectl` are installed on every node
- [x] Kubernetes packages are held against unintended upgrades
- [ ] `k8s-cpl-01` is initialized with kubeadm
- [ ] `k8s-wrk-01` has joined the cluster
- [ ] `k8s-wrk-02` has joined the cluster
- [ ] Cilium is installed with a pinned version
- [ ] All three nodes report `Ready`
- [ ] CoreDNS is healthy
- [ ] Cilium reports a healthy status
- [ ] Cilium connectivity tests pass
- [ ] Kubernetes API readiness checks pass
- [ ] No bootstrap credentials are stored in Git
- [ ] The bootstrap process has been tested after a clean rebuild
- [ ] Repository documentation reflects the completed implementation
````
