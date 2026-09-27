# Prerequisites: CAP015-010 — Workload Identity And Mutual TLS Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 010 — Workload Identity And Mutual TLS (all three modules)](../../../../README.md)** first. You should already be comfortable with:

- Everything from the section's three modules: identity, the three `PeerAuthentication` scopes, and the migration procedure.
- Reading an identity off a live certificate rather than assuming it.
- Narrowest-wins precedence, including `portLevelMtls`.
- Telling a transport rejection from an authorization denial.

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
