# Prerequisites: CAP015-020 — Authorization Policy Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 020 — Authorization Policy Fundamentals (both modules)](../../../../README.md)** first. You should already be comfortable with:

- Deny-by-default and the allow-nothing baseline.
- Rule anatomy, and that `ALLOW` policies combine as a union.
- The evaluation order, and using `DENY` as a backstop a later `ALLOW` cannot undo.
- Identity-based rules and their dependence on mTLS.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
