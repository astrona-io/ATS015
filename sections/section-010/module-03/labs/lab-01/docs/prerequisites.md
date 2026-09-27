# Prerequisites: LAB015-010-03 — Migrate A Namespace To STRICT mTLS

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 3 — Migrate A Namespace From PERMISSIVE To STRICT mTLS](../../../course.md)** first. You should already be comfortable with:

- Reading `connection_security_policy` off `istio_requests_total` on the receiving proxy.
- That sidecar injection is an admission webhook, so a namespace label only affects pods created afterwards.
- `portLevelMtls`, and that it takes a container port.
- That a client-side `DestinationRule` can break a `STRICT` server.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
