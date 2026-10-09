# Inspect Workload Identity And Certificates — Playground

- **Slug:** ats-015-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio and the Starfleet (the Istio docs'
Bookinfo sample, renamed), then waits for you. Use it next to the module's
parts to read the certificate (and the identity in it) that every workload
has. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the
configuration path. `astrona submit` and `astrona test` do not apply: there is
no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, `fortio`, and the `drifter` in the `outpost` namespace (no sidecar) |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies; every workload has its own service account except `fortio` and the `drifter` |
| `examples/01-identity/` | Identity-based `AuthorizationPolicy` examples for `probe` and `cargo`, plus the `spiffe://` mistake in `cases/` |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/overview.md` (end) | Exam-style practice tasks with solutions, now part of the guide |
