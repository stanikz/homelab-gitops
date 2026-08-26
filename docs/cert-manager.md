# cert-manager

cert-manager issues and automatically renews TLS certificates for services
behind the Cilium Gateway. Certificates are obtained from Let's Encrypt using
the Cloudflare DNS-01 challenge, so no inbound ports need to be opened — all
validation traffic is outbound from the cluster.

## What it provides

* Automated issuance and renewal of a wildcard certificate for
  `*.k8s.stanikz.com`.
* Integration with the Gateway API via the cert-manager gateway-shim: annotate
  the Gateway, and cert-manager issues the certificate for its TLS listener
  automatically. No manual `Certificate` resource is required.

## Install (bootstrap layer)

cert-manager is installed from the admin workstation with Helm, mirroring the
Cilium and Argo CD installs:

```text
kubernetes/ansible/roles/cert_manager/
kubernetes/ansible/playbooks/install-cert-manager.yml
```

Pinned version:

```text
cert-manager: v1.19.3
```

The version is pinned deliberately: recent cert-manager releases fixed a
breaking change in Cloudflare's API affecting DNS-01, so an older pin can fail
issuance.

The role:

* Installs cert-manager via Helm with its CRDs (`crds.enabled=true`).
* Enables the Gateway API integration (`config.enableGatewayAPI=true`).
* Waits for the controller, webhook and cainjector rollouts.
* Fetches the Cloudflare API token and ACME email from Bitwarden and creates
  the `cloudflare-api-token` secret (see below).
* Renders and applies the ClusterIssuers from a template.

## Secrets: Cloudflare token and ACME email from Bitwarden

The Cloudflare API token (for solving DNS-01) and the ACME account email are
sensitive and are **not** committed to Git. They are retrieved from Bitwarden at
run time, mirroring how the infrastructure layer retrieves RustFS credentials.

* The token is stored in the **notes** of a Bitwarden item.
* The email is stored in a **custom field** named `email` on the same item.

The item name is configured in the role defaults:

```text
kubernetes/ansible/roles/cert_manager/defaults/main.yml
```

```yaml
cert_manager_bw_item: "Cloudflare API - Token for DNS"
cert_manager_dns_zone: "stanikz.com"
```

`BW_SESSION` must be exported in the environment when running the playbook, the
same as for the infrastructure layer:

```bash
export BW_SESSION="$(bw unlock --raw)"
```

The role fetches both values with `no_log: true` so they never appear in
Ansible output, and creates the `cloudflare-api-token` secret idempotently
(`kubectl create --dry-run=client -o yaml | kubectl apply -f -`) so re-runs and
rebuilds converge cleanly.

The DNS zone (`stanikz.com`) is kept in Git because it is already public in
Certificate Transparency logs; only the token and email are treated as secrets.

> This is the cluster's first in-cluster secret. It is created as a plain
> Kubernetes secret from Bitwarden for now. When the secret-management stack
> (OpenBao + External Secrets Operator) is introduced, this is the first
> credential that migrates: OpenBao holds the token, ESO syncs it, and Git holds
> only a reference.

## ClusterIssuers

Two ClusterIssuers are rendered from a template (the email is injected from
Bitwarden, so the rendered manifest is not committed to Git):

```text
kubernetes/ansible/roles/cert_manager/templates/cluster-issuers.yaml.j2
```

* `letsencrypt-staging` — Let's Encrypt staging. Untrusted by browsers, but has
  very high rate limits. Use while iterating and rebuilding.
* `letsencrypt-prod` — Let's Encrypt production. Real, browser-trusted
  certificates. Subject to rate limits (5 duplicate certs/week).

Both use the Cloudflare DNS-01 solver, scoped to the `stanikz.com` zone.

## How a certificate is issued

1. The Gateway carries the annotation
   `cert-manager.io/cluster-issuer: <issuer>` and has an HTTPS listener whose
   `certificateRefs` names the `k8s-wildcard-tls` secret.
2. cert-manager's gateway-shim sees the TLS listener and creates a
   `Certificate`, then an `Order` and a `Challenge`.
3. cert-manager creates a temporary `_acme-challenge` TXT record in Cloudflare,
   Let's Encrypt verifies it, and the record is cleaned up.
4. The signed certificate is written to the `k8s-wildcard-tls` secret in the
   `gateway` namespace, and the Gateway serves it. Renewal is automatic.

## Staging vs. production, and rebuilds

A `destroy -> apply -> bootstrap` rebuild wipes the cluster, so the certificate
and cert-manager's ACME account key are recreated and the certificate is
**re-issued** on the fresh cluster (it is not preserved).

* On **staging**, rebuild freely — rate limits are high.
* On **production**, each rebuild re-issues the wildcard and counts against the
  5 duplicate certs/week limit. Before a round of rebuild testing, switch the
  Gateway annotation to `letsencrypt-staging`; switch back to
  `letsencrypt-prod` once stable.

To switch issuer: change `cert-manager.io/cluster-issuer` in
`gitops/platform/gateway/gateway.yaml`, commit and push, then force
re-issuance:

```bash
kubectl -n gateway delete secret k8s-wildcard-tls
```

Persisting the certificate across rebuilds (to avoid re-issuance entirely) is
deferred to the secret-management stack (OpenBao + ESO).

## Validate

```bash
kubectl get clusterissuer                         # both Ready=True
kubectl -n gateway get certificate                # k8s-wildcard-tls Ready=True
kubectl -n gateway get order,challenge            # progress while pending
kubectl -n gateway describe challenge             # error detail if it stalls
```

Confirm the served certificate:

```bash
# bypass DNS, check the cert the Gateway serves
curl -vk --resolve test.k8s.stanikz.com:443:192.168.10.210 \
  https://test.k8s.stanikz.com 2>&1 | grep -i "issuer:\|subject:"
```

On production the issuer is `O=Let's Encrypt` (no "STAGING"), and browsers show
a trusted padlock.

## Troubleshooting

* **Challenge stuck pending past ~5 min:** usually the Cloudflare token lacks
  DNS-edit permission on the zone. `kubectl -n gateway describe challenge` shows
  the error.
* **No `Certificate` created at all:** the Gateway is missing the annotation or
  the HTTPS listener, or the gateway-shim is not enabled
  (`config.enableGatewayAPI=true`). Confirm the live Gateway shows both, and
  check `kubectl -n cert-manager logs deploy/cert-manager | grep -i gateway`.