# TODO

## Kubernetes Bootstrap

* [x] Configure Kubernetes node prerequisites with Ansible
* [x] Install and configure containerd
* [x] Install pinned `kubelet`, `kubeadm`, and `kubectl`
* [x] Bootstrap control plane
* [x] Automate worker node join
* [x] Automate SSH host-key refresh
* [x] Add Kubernetes bootstrap wrapper
* [x] Test complete bootstrap after clean VM rebuild
* [x] Install Cilium
* [x] Validate cluster networking
* [x] Validate CoreDNS
* [x] Validate Kubernetes API readiness
* [x] Validate all nodes reach `Ready`
* [x] Refresh local kubeconfig before Cilium installation
* [x] Validate full bootstrap flow including Cilium after clean VM rebuild
* [ ] Evaluate GitOps-managed Cilium
* [ ] Improve Helm idempotency
* [ ] Evaluate Hubble
* [ ] Evaluate kube-proxy replacement

## GitOps Platform

* [ ] Install Argo CD
* [ ] Configure Git reconciliation
* [ ] Install OpenBao

## Platform

* [ ] Monitoring
* [ ] Logging