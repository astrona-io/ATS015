# Prerequisites: CAP015-050 — Edge Authorization Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 050 — Authorization At The Edge](../../../../README.md)** first. You should already be comfortable with:

- Gateway-scoped policy placement and selectors.
- `ipBlocks` versus `remoteIpBlocks`, and `numTrustedProxies`.
- Path-scoped rules, so an edge policy does not close every hostname the gateway serves.
- `DENY` beating `ALLOW`, applied at the edge.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
