# Prerequisites: LAB015-030-02 — Authorize On A JWT Claim

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 2 — Authorize On JWT Claims](../../../course.md)** first. You should already be comfortable with:

- That a validated token's claims become `request.auth.claims[...]` attributes.
- `when` combination rules: values ORed, entries ANDed, a list claim matching on any element.
- That a missing claim fails closed under `ALLOW`.
- Why a claim rule should also carry `requestPrincipals`.

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
