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
* [x] Enable kube-proxy replacement (skipped at kubeadm init; Cilium handles service datapath)
* [x] Enable LB-IPAM and L2 announcements for bare-metal load balancing

## GitOps Platform

* [x] Install Argo CD
* [x] Configure Git reconciliation (app-of-apps root Application)
* [x] Cilium Gateway API ingress (shared Gateway, pinned IP)
* [x] cert-manager with automated Let's Encrypt certificates (Cloudflare DNS-01)
* [x] Expose Argo CD over HTTPS via the Gateway (off port-forward)
* [ ] Persist/restore TLS cert across rebuilds (via OpenBao/ESO)
* [ ] Install OpenBao

## Platform

* [ ] Monitoring
* [ ] Logging