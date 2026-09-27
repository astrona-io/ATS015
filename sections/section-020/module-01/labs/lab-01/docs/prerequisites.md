# Prerequisites: LAB015-020-01 — Lock A Namespace Down With ALLOW Policies

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Authorize HTTP Traffic Between Workloads](../../../course.md)** first. You should already be comfortable with:

- That an `ALLOW` policy with `spec: {}` selects everything and matches nothing.
- That default-deny is created by the first `ALLOW` policy selecting a workload.
- The `from` / `to` / `when` parts of a rule, and that all present parts must match.
- That `principals` needs mTLS, and how to write one correctly.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
