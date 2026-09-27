# Prerequisites: LAB015-020-02 — Close A Path With DENY

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 2 — DENY Policies And Evaluation Order](../../../course.md)** first. You should already be comfortable with:

- The `CUSTOM` → `DENY` → `ALLOW` evaluation order, and that a match at `DENY` ends the decision.
- That a workload selected only by `DENY` policies still allows everything else.
- Path matching: `/admin` versus `/admin*`.
- That an `ALLOW` cannot carve an exception out of a `DENY`.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
