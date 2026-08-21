#!/usr/bin/env bash

# Requires:
#   - Bitwarden CLI (bw)
#   - jq
#
# The Bitwarden item stores:
#   - Username -> RustFS S3 access key
#   - Password -> RustFS S3 secret key
#
# Credentials are retrieved at runtime and passed to Terragrunt
# through environment variables. They are not stored in this repository,
# Terraform/OpenTofu configuration, or state.
# Usage:
#   ./scripts/terragrunt-bw.sh run --all plan --working-dir infrastructure/live/test
#   ./scripts/terragrunt-bw.sh run --all apply --working-dir infrastructure/live/test
#   ./scripts/terragrunt-bw.sh run --all destroy --working-dir infrastructure/live/test

set -euo pipefail

ITEM_NAME="RustFS - tofu-state creds"

# Check required commands
if ! command -v bw >/dev/null 2>&1; then
  echo "Error: Bitwarden CLI (bw) is not installed." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed." >&2
  exit 1
fi

if ! command -v terragrunt >/dev/null 2>&1; then
  echo "Error: Terragrunt is not installed." >&2
  exit 1
fi

# Check that the Bitwarden vault is unlocked
BW_STATUS="$(bw status | jq -r '.status')"

if [[ "$BW_STATUS" != "unlocked" ]]; then
  echo "Error: Bitwarden vault is not unlocked." >&2
  echo "Run 'bw unlock' first and set BW_SESSION." >&2
  exit 1
fi

# Retrieve RustFS credentials from Bitwarden
ITEM="$(bw get item "$ITEM_NAME")"

AWS_ACCESS_KEY_ID="$(jq -r '.login.username // empty' <<< "$ITEM")"
AWS_SECRET_ACCESS_KEY="$(jq -r '.login.password // empty' <<< "$ITEM")"

if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "Error: RustFS access key is missing from Bitwarden item:" >&2
  echo "       $ITEM_NAME" >&2
  exit 1
fi

if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Error: RustFS secret key is missing from Bitwarden item:" >&2
  echo "       $ITEM_NAME" >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

# Run Terragrunt with the supplied arguments
exec terragrunt "$@"
