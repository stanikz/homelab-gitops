# Cilium

Cilium is used as the Kubernetes Container Network Interface (CNI) plugin for
the homelab cluster.

Cilium is installed with Ansible using the official Cilium Helm chart.

In addition to pod networking, Cilium provides the cluster's service datapath
(kube-proxy replacement) and bare-metal load balancing (LB-IPAM with L2
announcements), removing the need for kube-proxy and for a separate load
balancer such as MetalLB.

## Current Mode

Current validated cluster:

| Component | Status |
|-----------|--------|
| Kubernetes nodes | Ready |
| CoreDNS | Healthy |
| Cilium | Healthy |
| Cilium Operator | Healthy |
| kube-proxy | Replaced by Cilium (not installed) |
| LB-IPAM | Enabled |
| L2 announcements | Enabled |

Cilium runs in kube-proxy replacement mode. kube-proxy is not installed on the
cluster: the kubeadm `addon/kube-proxy` phase is skipped during control-plane
initialization, so no kube-proxy DaemonSet is ever created. Cilium handles all
service load balancing in its eBPF datapath.

Kube-proxy replacement is a prerequisite for Cilium L2 announcements, which are
used to make `LoadBalancer` service IPs reachable on the local network.

## Service Load Balancing

Because this is a bare-metal cluster with no cloud provider, `LoadBalancer`
services are handled entirely by Cilium:

* **LB-IPAM** allocates an external IP to each `LoadBalancer` service from a
  reserved pool on the node subnet.
* **L2 announcements** make that IP reachable on the LAN by answering ARP
  requests for it on the node interface.

These two mechanisms are separate: LB-IPAM assigns the IP, L2 announcements make
it reachable.

### Reserved IP range

The load balancer pool is `192.168.10.210`–`192.168.10.220`. This range is
reserved at the router: the DHCP pool ends at `192.168.10.209`, so nothing else
on the LAN leases into this band.

The pool and the announcement policy are Kubernetes custom resources managed via
GitOps (reconciled by Argo CD), not part of the Cilium Helm installation. This
keeps per-cluster policy (which IP range, which interface) separate from the
Cilium install itself. See:

```text
gitops/platform/networking/lb-ippool.yaml
gitops/platform/networking/l2-announcement.yaml
```

`CiliumLoadBalancerIPPool` (`cilium.io/v2`) defines the pool.
`CiliumL2AnnouncementPolicy` (`cilium.io/v2alpha1`) announces the IPs on the
`eth0` interface, which carries the `192.168.10.0/24` subnet on all nodes.

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

### Helm values

The install task sets the following, all driven by role defaults so a different
cluster can override them without editing the role:

| Helm value | Default | Purpose |
|------------|---------|---------|
| `kubeProxyReplacement` | `true` | Cilium replaces kube-proxy in the service datapath |
| `k8sServiceHost` | `k8s-cpl-01.home` | API server endpoint Cilium uses directly (required with kube-proxy replacement) |
| `k8sServicePort` | `6443` | API server port |
| `l2announcements.enabled` | `true` | Enable L2 announcement of service IPs |
| `externalIPs.enabled` | `true` | Enable service load balancing for external IPs |

`k8sServiceHost` and `k8sServicePort` are required in kube-proxy replacement
mode: without kube-proxy, Cilium cannot rely on it to reach the API server and
must be told the endpoint directly, or the Cilium agents will not start.

Defaults are defined in:

```text
kubernetes/ansible/roles/cilium/defaults/main.yml
```

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

Confirm kube-proxy is not present (it is intentionally skipped at kubeadm init):

```bash
kubectl -n kube-system get ds kube-proxy
# Expected: No resources found
```

## Local Kubeconfig Refresh

After a clean cluster rebuild, the local kubeconfig must be refreshed before
installing Cilium.

The kubeconfig contains the Kubernetes cluster certificate authority. Because a new kubeadm cluster generates a new certificate authority, an old kubeconfig from a previous cluster rebuild will fail TLS verification against the new API server.

The main bootstrap script handles this automatically by copying the kubeconfig from the control-plane node after kubeadm initialization and before Cilium installation.

```bash
scp ubuntu@k8s-cpl-01.home:/home/ubuntu/.kube/config ~/.kube/homelab.yaml
```

This kubeconfig must be active in the shell running Helm or kubectl:

```bash
export KUBECONFIG=~/.kube/homelab.yaml
```

If `KUBECONFIG` is not exported, kubectl and Helm fall back to `~/.kube/config`,
which may hold a stale context from a previous cluster and will fail TLS
verification against the rebuilt API server.

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

Confirm kube-proxy is not installed:

```bash
kubectl -n kube-system get ds kube-proxy
# Expected: No resources found
```

### Validate load balancing

Confirm the pool exists and has addresses available:

```bash
kubectl get ciliumloadbalancerippool
kubectl get ciliuml2announcementpolicy
```

Create a temporary `LoadBalancer` service and confirm it receives a reachable
IP from the pool:

```bash
kubectl create deploy nginx-test --image=nginx
kubectl expose deploy nginx-test --type=LoadBalancer --port=80
kubectl get svc nginx-test          # EXTERNAL-IP in 192.168.10.210-220
curl http://<external-ip>           # reachable from the LAN
kubectl delete deploy,svc nginx-test
```

## Validated Result

The current cluster has been validated, on a clean VM rebuild, with:

```text
k8s-cpl-01   Ready
k8s-wrk-01   Ready
k8s-wrk-02   Ready
```

Cilium pods are running on all Kubernetes nodes.

The Cilium operator is running with two replicas.

CoreDNS is running with two available replicas.

kube-proxy is not installed.

A test `LoadBalancer` service received an IP from `192.168.10.210`–`.220` and
was reachable from the LAN, confirming LB-IPAM and L2 announcements both work.

## Future Work

Future Cilium improvements may include:

* Improved Helm idempotency using the Ansible Helm module.
* Hubble.
* Network policies.
* Cilium Gateway API for ingress (single entry point, hostnames, TLS).
* GitOps-managed Cilium installation through Argo CD.