# Prerequisites: LAB015-040-03 — Route An Encrypted Stream By SNI

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 3 — TLS Passthrough Instead Of Termination](../../../course.md)** first. You should already be comfortable with:

- That SNI is the only routable field in an encrypted stream.
- `protocol: TLS` with `mode: PASSTHROUGH`, and no `credentialName`.
- That passthrough routes with a `VirtualService` `tls` block on `sniHosts`, never an `http` block.
- That the backend, not the gateway, presents the certificate.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.
- `openssl` — provided by the lab environment.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
