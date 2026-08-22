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
* [ ] Install Cilium
* [ ] Validate cluster networking
* [ ] Validate CoreDNS
* [ ] Validate Kubernetes API readiness
* [ ] Validate all nodes reach `Ready`

## GitOps Platform

* [ ] Install Argo CD
* [ ] Configure Git reconciliation
* [ ] Install OpenBao

## Platform

* [ ] Monitoring
* [ ] Logging