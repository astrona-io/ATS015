# Prerequisites: LAB015-040-02 — Require Client Certificates At The Edge

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.prerequisites`.
> Read this before the [exam question](./exam-question.md).

## Knowledge

Work through **[Module 2 — Require Client Certificates At The Edge](../../../course.md)** first. You should already be comfortable with:

- That `MUTUAL` needs a third secret key, `ca.crt`, and why `create secret tls` cannot build it.
- That a rejected client fails in the handshake — a `curl` error and `000`, never `403`.
- That a misconfigured `MUTUAL` gateway fails **open**, so a successful request proves nothing.
- Reading `requireClientCertificate` off the gateway listener.

## Tooling

- The `astrona` CLI (`astrona run` / `submit` / `destroy`).
- `kubectl`, and Docker or Podman running — the lab provisions a `kind` cluster.
- `istioctl`, installed into the environment by the bootstrap; you do not need it locally.
- `openssl` — provided by the lab environment.
- `openssl`, plus a CA and two leaf certificates the bootstrap leaves in `/tmp` for you.

## Not required

- You do not install Istio — the bootstrap installs **Istio 1.30.5** with the `demo` profile.
- You do not create the starting workloads — they are applied for you.
- You do not grade yourself; `astrona submit` runs the checks.

Ready? Go to the [exam question](./exam-question.md).
