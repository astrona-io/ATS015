# Prerequisites: LAB015-060-01 — Enforce L4 And L7 Policy In Ambient Mode

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Authorization In Ambient Mode, L4 And L7](../../../course.md)** first. You should already be comfortable with:

- The ztunnel / waypoint split, and that ztunnel does mTLS over HBONE but never parses HTTP.
- Which `AuthorizationPolicy` fields work at L4 and which need a waypoint.
- `targetRefs` attachment versus a label `selector`.
- That an L4 denial is a connection error and an L7 denial is a `403`.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `ambient` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
