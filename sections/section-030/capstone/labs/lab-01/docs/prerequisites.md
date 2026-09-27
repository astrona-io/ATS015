# Prerequisites: CAP015-030 — End-User Authentication Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 030 — End-User Authentication With JWT (both modules)](../../../../README.md)** first. You should already be comfortable with:

- `RequestAuthentication` plus `requestPrincipals` as a pair.
- Claim matching with `when`, including list claims.
- That peer identity and request identity can be required in the same rule.
- `401` versus `403`, and which object each points at.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

> **Outbound internet is required.** This lab uses Istio's published demo tokens and the
> matching JWKS endpoint on `raw.githubusercontent.com`.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
