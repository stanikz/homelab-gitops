# Roadmap

## Stage 1 — Infrastructure

* [x] Proxmox
* [x] OpenTofu
* [x] Terragrunt
* [x] Cloud-Init
* [x] Remote OpenTofu state
* [x] Bitwarden-backed backend authentication

## Stage 2 — Kubernetes Bootstrap

* [x] Ansible node preparation
* [x] containerd
* [x] Kubernetes packages
* [x] kubeadm control-plane bootstrap
* [x] Worker node join
* [x] Automated bootstrap entry point
* [x] Local kubeconfig refresh after rebuild
* [x] Clean rebuild validation
* [x] Cilium
* [x] Cluster validation
* [x] Cilium kube-proxy replacement, LB-IPAM and L2 announcements

## Stage 3 — GitOps Platform

* [x] Argo CD
* [x] Cilium Gateway API ingress
* [x] cert-manager (Let's Encrypt, Cloudflare DNS-01)
* [ ] OpenBao
* [ ] Monitoring
* [ ] Logging

## Stage 4 — Applications

* [ ] GitOps applications