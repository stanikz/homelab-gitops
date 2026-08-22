#!/usr/bin/env bash

set -euo pipefail

KNOWN_HOSTS="${HOME}/.ssh/known_hosts"

nodes=(
  "k8s-cpl-01:k8s-cpl-01.home:192.168.10.170"
  "k8s-wrk-01:k8s-wrk-01.home:192.168.10.171"
  "k8s-wrk-02:k8s-wrk-02.home:192.168.10.172"
)

mkdir -p "${HOME}/.ssh"
touch "${KNOWN_HOSTS}"

chmod 700 "${HOME}/.ssh"
chmod 600 "${KNOWN_HOSTS}"

for node in "${nodes[@]}"; do
  IFS=":" read -r short_hostname fqdn ip <<< "${node}"

  echo "Refreshing SSH host keys for ${fqdn} (${ip})..."

  # Remove all possible identities belonging to the previous VM.
  ssh-keygen -R "${short_hostname}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1 || true
  ssh-keygen -R "${fqdn}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1 || true
  ssh-keygen -R "${ip}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1 || true

  echo "Waiting for SSH on ${fqdn}..."

  attempts=0
  max_attempts=30
  scan_file="$(mktemp)"

  until ssh-keyscan -T 5 "${fqdn}" > "${scan_file}" 2>/dev/null && [[ -s "${scan_file}" ]]; do
    attempts=$((attempts + 1))

    if (( attempts >= max_attempts )); then
      echo "ERROR: Unable to retrieve SSH host key from ${fqdn}."
      rm -f "${scan_file}"
      exit 1
    fi

    sleep 2
  done

  # Add the keys using all names by which we may connect to this VM.
  ssh-keyscan -T 5 -H "${short_hostname}" >> "${KNOWN_HOSTS}" 2>/dev/null
  ssh-keyscan -T 5 -H "${fqdn}" >> "${KNOWN_HOSTS}" 2>/dev/null
  ssh-keyscan -T 5 -H "${ip}" >> "${KNOWN_HOSTS}" 2>/dev/null

  rm -f "${scan_file}"

  echo "SSH host keys updated for ${fqdn}."
done

echo
echo "Kubernetes SSH host keys refreshed successfully."