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
* [ ] Improve Cilium Helm idempotency with Ansible Helm module
* [ ] Decide whether to keep kube-proxy or rebuild later with Cilium kube-proxy replacement
* [ ] Evaluate Hubble
* [ ] Evaluate GitOps-managed Cilium installation

## GitOps Platform

* [ ] Install Argo CD
* [ ] Configure Git reconciliation
* [ ] Install OpenBao

## Platform

* [ ] Monitoring
* [ ] Logging