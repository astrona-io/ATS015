# Prerequisites: LAB015-050-01 — Block A Client Range At The Gateway

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Authorize By Source IP At The Ingress Gateway](../../../course.md)** first. You should already be comfortable with:

- That a gateway-scoped policy lives in the gateway's namespace and selects the gateway pod.
- `ipBlocks` (the connection peer) versus `remoteIpBlocks` (the client from `X-Forwarded-For`).
- What `numTrustedProxies` pins, and why `remoteIpBlocks` is spoofable without it.
- That a gateway denial is an ordinary `403`.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
