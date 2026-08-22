#!/usr/bin/env bash

set -euo pipefail

KNOWN_HOSTS="${HOME}/.ssh/known_hosts"

nodes=(
  "k8s-cpl-01.home:192.168.10.170"
  "k8s-wrk-01.home:192.168.10.171"
  "k8s-wrk-02.home:192.168.10.172"
)

mkdir -p "${HOME}/.ssh"
touch "${KNOWN_HOSTS}"

chmod 700 "${HOME}/.ssh"
chmod 600 "${KNOWN_HOSTS}"

for node in "${nodes[@]}"; do
  fqdn="${node%%:*}"
  ip="${node##*:}"

  echo "Refreshing SSH host key for ${fqdn} (${ip})..."

  #
  # Remove keys from previous VM instances.
  #
  ssh-keygen -R "${fqdn}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1 || true
  ssh-keygen -R "${ip}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1 || true

  #
  # Wait until SSH is available and retrieve the new host keys.
  #
  attempts=0
  max_attempts=30

  while true; do
    scanned_keys="$(ssh-keyscan -T 5 -H "${fqdn}" 2>/dev/null || true)"

    if [[ -n "${scanned_keys}" ]]; then
      break
    fi

    attempts=$((attempts + 1))

    if (( attempts >= max_attempts )); then
      echo "ERROR: Unable to retrieve SSH host key from ${fqdn}."
      exit 1
    fi

    echo "Waiting for SSH on ${fqdn}..."
    sleep 2
  done

  printf '%s\n' "${scanned_keys}" >> "${KNOWN_HOSTS}"

  echo "SSH host key updated for ${fqdn}."
done

echo
echo "Kubernetes SSH host keys refreshed successfully."