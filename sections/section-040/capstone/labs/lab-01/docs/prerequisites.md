# Prerequisites: CAP015-040 — Edge TLS Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Section 040 — Securing Edge Traffic With TLS (all three modules)](../../../../README.md)** first. You should already be comfortable with:

- All three gateway TLS modes and when each is correct.
- The credential secret layouts, and the gateway-namespace rule.
- SNI-based listener selection across several `servers` entries.
- That passthrough gives up every L7 capability for that hostname.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.
- `openssl` — provided by the lab environment.
- `openssl`, plus certificate material the bootstrap leaves in `/tmp` for you.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
