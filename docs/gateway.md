# Gateway API

The cluster uses the Cilium Gateway API as its single ingress entry point.
Cilium is the Gateway controller (using its Envoy datapath), so there is no
separate ingress controller such as ingress-nginx, and no `Ingress` resources.

TLS for services behind the Gateway is provided by cert-manager (see
`docs/cert-manager.md`).

## Why Gateway API

Gateway API is the successor to the older Kubernetes `Ingress` API. Cilium
already implements it, so adopting it needs no extra controller — it reuses the
CNI that is already installed. Routing, hostnames and TLS are expressed as
declarative resources reconciled from Git by Argo CD.

## Prerequisites (bootstrap layer)

Gateway API has two prerequisites, both handled by the Cilium Ansible role
because they are foundational and must exist before Cilium can program
Gateways:

* **Gateway API CRDs** — installed by the role via
  `kubectl apply --server-side` from the upstream release. Pinned to the
  version supported by the installed Cilium:

  ```text
  Gateway API CRDs: v1.6.1 (standard channel)
  Cilium:           1.20.1
  ```

  The CRDs are installed by hand (not via GitOps) because Cilium is the CNI and
  a prerequisite for all workloads, including Argo CD. Installing them in the
  role keeps the CRDs and the `gatewayAPI.enabled` flag together as one
  coherent change.

* **`gatewayAPI.enabled=true`** — a Cilium Helm value set in the Cilium role.

Relevant role defaults:

```text
kubernetes/ansible/roles/cilium/defaults/main.yml
```

```yaml
cilium_gateway_api_enabled: "true"
cilium_gateway_api_crds_version: "v1.6.1"
cilium_gateway_api_crds_url: "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml"
```

## The Gateway (GitOps layer)

The Gateway resource itself is per-cluster policy and is managed via GitOps:

```text
gitops/platform/gateway/gateway.yaml
```

Key properties:

* **Name / namespace:** `cilium-gateway` in the dedicated `gateway` namespace.
  The Gateway is shared infrastructure, so it lives in its own namespace rather
  than in `kube-system` or any single app's namespace.
* **Pinned IP:** the LoadBalancer service Cilium creates for the Gateway is
  pinned to `192.168.10.210` via the `io.cilium/lb-ipam-ips` annotation, so the
  Pi-hole wildcard (`*.k8s.stanikz.com` -> `192.168.10.210`) always resolves to
  it. The IP is allocated from the Cilium LB-IPAM pool (see `docs/cilium.md`).
* **Listeners:** an HTTP listener on port 80 and an HTTPS listener on port 443,
  both for hostname `*.k8s.stanikz.com`. The HTTPS listener terminates TLS
  using the `k8s-wildcard-tls` secret, which cert-manager populates.
* **cert-manager annotation:** `cert-manager.io/cluster-issuer` selects the
  ACME issuer used to obtain the certificate (see `docs/cert-manager.md`).
* **allowedRoutes: from All** — each application keeps its own `HTTPRoute` in
  its own namespace and attaches to this Gateway.

## Routing model

Routes are attached to the shared Gateway from the application's own namespace
using `parentRefs`. This is the standard Gateway API cross-namespace pattern:

```text
Gateway  (namespace: gateway)          <- one shared entry point, one IP
   ^
   | parentRef
   |
HTTPRoute (namespace: <app>)           <- one per app, hostname-based
   -> Service (ClusterIP)              <- backend, consumes no LB IP
```

Because every route shares the single Gateway IP and is separated by hostname,
only one IP from the LB pool is consumed for all HTTP/HTTPS services. Backends
stay `ClusterIP` and consume no pool addresses.

Example: Argo CD's route lives in the `argocd` namespace and attaches to
`cilium-gateway`:

```text
gitops/platform/argocd/httproute.yaml
```

## DNS

`*.k8s.stanikz.com` resolves to the Gateway IP (`192.168.10.210`) via a
wildcard entry on the LAN's Pi-hole DNS server (a dnsmasq `address=` entry, as
the Pi-hole web UI only supports exact names). One wildcard covers every
current and future service under `*.k8s.stanikz.com`.

## Validate

Check the GatewayClass and Gateway:

```bash
kubectl get gatewayclass                              # cilium — ACCEPTED
kubectl -n gateway get gateway cilium-gateway         # PROGRAMMED=True, ADDRESS=192.168.10.210
```

Check a route:

```bash
kubectl -n <app-namespace> get httproute
```

Test routing directly, independent of DNS:

```bash
curl -H "Host: test.k8s.stanikz.com" http://192.168.10.210
```

Test through DNS (from a host that uses Pi-hole):

```bash
curl http://test.k8s.stanikz.com
```

Note: the Gateway IP answers HTTP/HTTPS, not ICMP — `ping 192.168.10.210` will
not respond and is not a useful health check.

## Future work

* HTTP-to-HTTPS redirect on the HTTP listener.
* gRPC routing for the Argo CD CLI (the web UI works over the HTTPRoute today).
* Move additional platform UIs (Hubble, monitoring) behind the same Gateway.