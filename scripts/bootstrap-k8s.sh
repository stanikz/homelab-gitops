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
echo "Installing Cilium CNI..."

ansible-playbook playbooks/install-cilium.yml

echo
echo "Kubernetes node preparation completed successfully."