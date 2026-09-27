# Prerequisites: LAB015-040-01 — Serve HTTPS At The Ingress Gateway

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 1 — Terminate TLS At The Ingress Gateway](../../../course.md)** first. You should already be comfortable with:

- That `credentialName` is a bare name resolved in the **gateway pod's** namespace.
- The `tls.crt` / `tls.key` secret layout, and `kubectl create secret tls`.
- That a TLS listener needs `protocol: HTTPS` and a port name starting `https`.
- That SNI selects the listener while the `Host` header selects the route.

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
