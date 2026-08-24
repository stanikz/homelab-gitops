# Argo CD

Argo CD is the GitOps platform for this cluster. It is the first component of
Stage 3 and establishes the reconciliation loop that manages Kubernetes
resources after the base cluster is available.

This document records the architecture, the bootstrap mechanism, and the
operational behavior that was validated for the initial Argo CD installation.

---

## Role in the architecture

The project separates responsibilities into distinct layers:

```text
Infrastructure (OpenTofu/Terragrunt)
        ↓
Kubernetes bootstrap (Ansible + kubeadm + Cilium)
        ↓
GitOps platform (Argo CD)          ← this document
        ↓
Platform services (OpenBao, monitoring, logging)
        ↓
Applications
```

Everything up to and including Cilium is installed imperatively by
`scripts/bootstrap-k8s.sh`. Argo CD is the first component that introduces an
in-cluster reconciliation loop: once it is running, resources committed to Git under `gitops/platform/` are applied to the cluster automatically.

---

## Why Argo CD is installed imperatively

Installing the reconciler with the reconciler would be circular. To avoid this, Argo CD is installed the same way Cilium is — as a Helm-based Ansible role that runs from the admin workstation as the final step of the bootstrap.

This keeps the bootstrap dependency explicit and non-circular:

* The imperative bootstrap (Ansible + Helm) installs Argo CD.
* Argo CD then manages everything above it declaratively.

The relevant files are:

```text
kubernetes/ansible/roles/argocd/
kubernetes/ansible/playbooks/install-argocd.yml
```

`scripts/bootstrap-k8s.sh` runs `install-argocd.yml` after Cilium, so Argo CD is installed only once the CNI is up and all nodes are `Ready`.

---

## Repository layout

GitOps content lives in a dedicated top-level directory, separate from the
provisioning and bootstrap layers:

```text
gitops/
├── bootstrap/
│   └── root-app.yaml            # app-of-apps root Application
└── platform/
    └── namespaces/
        └── platform-namespaces.yaml
```

`gitops/` is intentionally self-contained. It contains only the resources Argo CD reconciles, not the Ansible that installs Argo CD. This keeps the boundary between "what installs the reconciler" and "what the reconciler manages" visible, and would make a future split into a separate GitOps repository clean.

---

## GitOps model: app-of-apps

The cluster uses the **app-of-apps** pattern. A single root `Application`
(`gitops/bootstrap/root-app.yaml`) points at `gitops/platform/` with directory
recursion enabled. Every manifest placed under `gitops/platform/` is discovered
and reconciled automatically.

App-of-apps was chosen over `ApplicationSet` because this is a single-cluster
homelab with no fan-out to generate. `ApplicationSet` earns its complexity when
generating many similar Applications across many clusters or tenants, which does
not apply here. If a second cluster or many near-identical apps are introduced
later, individual children can be converted to an `ApplicationSet`
non-destructively.

The root app has automated sync enabled (`prune` and `selfHeal`), so drift is
corrected and removed files are pruned.

---

## The root app is a bootstrap anchor

An important operational property: **Argo CD reconciles the content the root app
points at, but it does not reconcile the root app's own spec.**

* The `platform` namespace and everything under `gitops/platform/` are managed
  by Argo CD. Committing a manifest there is enough — Argo CD applies it.
* The root `Application` object itself (including its `spec.source.targetRevision`)
  is **not** self-managed. Editing `root-app.yaml` in Git does not update the
  live root object. It must be re-applied.

The mechanism that keeps the live root app in sync with Git is the
`install-argocd.yml` playbook, which re-applies `root-app.yaml` on every
bootstrap run. On a normal clean rebuild, the root app therefore always matches
Git.

The only time a manual re-apply is required is when `root-app.yaml` is edited
**between** bootstrap runs (for example, changing `targetRevision`). In that
case:

```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```

A self-referential root app (one that reconciles its own `bootstrap/` path) is
possible but deliberately not used here: a bad commit to the root app could
break the thing managing it. The explicit model — root app applied by the
bootstrap playbook, everything else via GitOps — is simpler to reason about and
recover.

---

## Configuration

The Argo CD Helm chart version is pinned in the role defaults:

```text
kubernetes/ansible/roles/argocd/defaults/main.yml
```

```yaml
argocd_chart_version: "10.4.0"
argocd_namespace: argocd
```

The root app's `repoURL` points at this repository over HTTPS. The repository is
public, so Argo CD reads it anonymously and no repository credentials are
required.

---

## kubeconfig requirement

Argo CD is installed from the admin workstation using the local `kubectl`
context and the local Helm binary, exactly like Cilium. The bootstrap refreshes
the local kubeconfig from the control-plane node into:

```text
~/.kube/homelab.yaml
```

This kubeconfig must be active in the shell that runs the playbook or any
`kubectl`/`helm` command against the cluster:

```bash
export KUBECONFIG=~/.kube/homelab.yaml
```

If `KUBECONFIG` is not exported, `kubectl` and Helm fall back to
`~/.kube/config`, which may contain a stale context from a previous cluster and
will fail TLS verification against the rebuilt API server:

```text
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

The fix is to export the homelab kubeconfig (and, after a rebuild, re-pull it
from the control-plane node). Consider exporting `KUBECONFIG` from a shell
profile to avoid this recurring.

---

## Version upgrades

The Argo CD version is pinned. Upgrading is a deliberate change to
`argocd_chart_version`, not something a re-run performs on its own —
`helm upgrade --install` converges to the pinned version and does not drift to
whatever is newest upstream.

When deliberately upgrading, note the Argo CD **CRD caveat**: Helm installs CRDs
on first install but does not upgrade them on subsequent `helm upgrade` runs. If
a newer chart ships changed CRDs, the Deployments will update but the CRDs will
not, which can cause subtle breakage. Always read the chart's upgrade notes and
apply new CRDs explicitly if the notes call for it.

---

## Accessing the UI

Access is currently via port-forward. A stable LoadBalancer/ingress address is a
later increment (Cilium LB-IPAM + L2 announcements, then Gateway API), which
requires enabling kube-proxy replacement in the Cilium install.

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Browse to `https://localhost:8080` and log in as `admin`.

---

## Validation

The following was validated for the initial installation:

* All Argo CD components reach `Running` (`kubectl -n argocd get pods`).
* The root `Application` reports `Synced` / `Healthy`
  (`kubectl -n argocd get application root`).
* The `platform` namespace is created by Argo CD from Git, with no manual
  `kubectl create` (`kubectl get ns platform`), proving the reconciliation loop
  end to end.

---

## Next steps

* Move Argo CD off port-forward once the cluster network layer (kube-proxy
  replacement, Cilium LB-IPAM, L2 announcements, Gateway API) is in place.
* Add platform services under `gitops/platform/` (OpenBao, monitoring, logging),
  each reconciled automatically by the root app.
* Introduce secret management (OpenBao + External Secrets Operator) so that Git
  holds only references, never secret values.