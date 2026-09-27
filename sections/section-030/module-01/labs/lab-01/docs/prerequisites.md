# Prerequisites: LAB015-030-01 — Require A Valid End-User Token

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Authenticate End Users With JWT](../../../course.md)** first. You should already be comfortable with:

- That `RequestAuthentication` validates a token if one is present and requires nothing.
- `issuer` matching the `iss` claim exactly, and what `jwksUri` is for.
- That `requestPrincipals` in an `AuthorizationPolicy` is what makes a token mandatory.
- The difference between `401` (bad token) and `403` (refused request).

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
