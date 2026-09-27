# Prerequisites: CAP015-060 — Ambient Authorization Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 060 — Authorization In Ambient Mode](../../../../README.md)** first. You should already be comfortable with:

- The L4/L7 enforcement split and its attachment rules.
- That an unenforced policy is indistinguishable from an enforced one in `kubectl get`.
- Deploying **and enrolling** a waypoint.
- `istioctl ztunnel-config` for finding out which component holds which policy.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `ambient` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
