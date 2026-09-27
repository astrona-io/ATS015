# Prerequisites: LAB015-010-01 — Prove A Workload Identity And Authorize On It

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Inspect Workload Identity And Certificates](../../../course.md)** first. You should already be comfortable with:

- That a workload's mesh identity is `<trust-domain>/ns/<namespace>/sa/<service-account>`, derived from its service account.
- Reading a certificate's SAN with `istioctl proxy-config secret` and `openssl x509`.
- That `principals` takes the identity **without** the `spiffe://` scheme.
- Why an identity-based rule needs mTLS to match at all.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.
- `openssl` — provided by the lab environment.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
