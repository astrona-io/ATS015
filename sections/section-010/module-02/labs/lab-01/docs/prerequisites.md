# Prerequisites: LAB015-010-02 — Enforce mTLS At Three Scopes

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 2 — Enforce mTLS With PeerAuthentication At Three Scopes](../../../course.md)** first. You should already be comfortable with:

- The four `PeerAuthentication` modes and what each does to an inbound listener.
- That scope is decided by namespace plus the presence of a `selector` — not by a field.
- The narrowest-wins precedence rule across mesh, namespace and workload.
- That a `STRICT` rejection is a connection reset (`000`), not a `403`.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
