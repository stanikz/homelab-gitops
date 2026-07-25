# Repository Structure

```text
homelab-gitops/

apps/
    GitOps-managed applications.

infrastructure/
    Infrastructure provisioning.

    live/
        Terragrunt environments.

    modules/
        Reusable OpenTofu modules.

k8s/
    Kubernetes bootstrap.

platform/
    Platform services deployed after Kubernetes.
```