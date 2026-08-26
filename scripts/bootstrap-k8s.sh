#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/kubernetes/ansible"

echo "Refreshing Kubernetes SSH host keys..."
"${SCRIPT_DIR}/refresh-k8s-known-hosts.sh"

echo
echo "Checking Ansible connectivity..."

cd "${ANSIBLE_DIR}"

ansible kubernetes -m ping

echo
echo "Preparing Kubernetes nodes..."

ansible-playbook playbooks/prepare-nodes.yml

echo
echo "Refreshing local kubeconfig..."

KUBECONFIG_PATH="${HOME}/.kube/homelab.yaml"

if [[ ! -d "${HOME}/.kube" ]]; then
  mkdir "${HOME}/.kube"
fi

scp ubuntu@k8s-cpl-01.home:/home/ubuntu/.kube/config "${KUBECONFIG_PATH}"

export KUBECONFIG="${KUBECONFIG_PATH}"

kubectl get nodes

echo
echo "Installing Cilium CNI..."

ansible-playbook playbooks/install-cilium.yml

echo
echo "Kubernetes node preparation completed successfully."


echo
echo "Installing Argo CD..."

ansible-playbook playbooks/install-argocd.yml

echo
echo "Installing cert-manager..."
ansible-playbook playbooks/install-cert-manager.yml