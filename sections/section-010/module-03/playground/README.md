# Migrate A Namespace From PERMISSIVE To STRICT mTLS — Playground

- **Slug:** ats-015-playground-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A local sandbox: it starts a `kind` cluster with Istio, the Starfleet (the
Istio docs' Bookinfo sample, renamed) and one client pod without a sidecar,
`drifter`, that still sends plain-text requests. Then it keeps running for you.
Use it alongside the module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-010-03
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, and namespace `outpost` without injection with the `drifter` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-migrate-to-strict/` | The migration in order: `PERMISSIVE` written down, then `STRICT`; plus the client-side mistake in `cases/` |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/overview.md` (end) | Exam-style practice tasks with solutions, now part of the guide |
