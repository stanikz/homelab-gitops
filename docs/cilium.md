# Cilium

Cilium is used as the Kubernetes Container Network Interface (CNI) plugin for
the homelab cluster.

Cilium is installed with Ansible using the official Cilium Helm chart.

## Current Mode

Current Cilium mode:

```text
CNI: Cilium
Installation method: Ansible + Helm
Namespace: kube-system
kube-proxy replacement: disabled
kube-proxy: enabled
```

The initial installation keeps kube-proxy enabled. Cilium kube-proxy replacement is intentionally left as future work because it requires a deliberate cluster bootstrap decision.

## Ansible Role

Cilium is installed by the Ansible role:

```text
kubernetes/ansible/roles/cilium
```

The role performs the following actions:

* Adds the official Cilium Helm repository.
* Updates Helm repositories.
* Installs or upgrades Cilium with Helm.
* Waits for the Cilium DaemonSet rollout.
* Waits for the Cilium operator rollout.
* Waits for all Kubernetes nodes to become `Ready`.
* Checks CoreDNS health.
* Restarts CoreDNS only if the rollout is unhealthy.
* Waits for CoreDNS to become healthy.

## Playbook

The Cilium playbook is:

```text
kubernetes/ansible/playbooks/install-cilium.yml
```

It runs on `localhost` because Cilium is installed from the admin workstation
using the current local `kubectl` context and the local Helm binary.

```yaml
---
- name: Install Cilium CNI
  hosts: localhost
  connection: local
  gather_facts: false
  become: false

  vars:
    ansible_become: false

  roles:
    - cilium
```

The explicit `become: false` and `ansible_become: false` settings are important because the Kubernetes node inventory uses privilege escalation for remote host configuration. Local Helm and kubectl commands should not run with sudo.

## Prerequisites

The Kubernetes cluster must already be bootstrapped with kubeadm.

Before installing Cilium, the nodes are expected to be in the `NotReady` state because no CNI plugin has been installed yet.

Check the current node state:

```bash
kubectl get nodes -o wide
```

Check kube-system pods:

```bash
kubectl -n kube-system get pods -o wide
```

Check kube-proxy:

```bash
kubectl -n kube-system get ds kube-proxy
```

In the current cluster, kube-proxy is enabled and runs on all Kubernetes nodes.

## Local Kubeconfig Refresh

After a clean cluster rebuild, the local kubeconfig must be refreshed before
installing Cilium.

The kubeconfig contains the Kubernetes cluster certificate authority. Because a new kubeadm cluster generates a new certificate authority, an old kubeconfig from a previous cluster rebuild will fail TLS verification against the new API server.

The main bootstrap script handles this automatically by copying the kubeconfig from the control-plane node after kubeadm initialization and before Cilium installation.

```bash
scp ubuntu@k8s-cpl-01.home:/home/ubuntu/.kube/config ~/.kube/homelab.yaml
```

## Install Cilium

Cilium is installed automatically as part of the main Kubernetes bootstrap flow:

```bash
./scripts/bootstrap-k8s.sh
```

## Validate Cilium

Check node readiness:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

Check Cilium pods:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

Check the Cilium operator:

```bash
kubectl -n kube-system get deployment cilium-operator
```

Check CoreDNS:

```bash
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
```

## Validated Result

The current cluster has been validated with:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

Cilium pods are running on all Kubernetes nodes.

The Cilium operator is running with two replicas.

CoreDNS is running with two available replicas.

## Future Work

Future Cilium improvements may include:

* Improved Helm idempotency using the Ansible Helm module.
* Hubble.
* Network policies.
* GitOps-managed Cilium installation through Argo CD.
* Cilium kube-proxy replacement.