# Inspect Workload Identity And Certificates — Playground

- **Slug:** ats-015-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with Istio
and the Starfleet (the Istio docs' Bookinfo sample, renamed), then waits for
you, astronaut. Use it next to the module's parts to read the ID badge
(certificate) every ship carries. Nothing to submit.

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
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, `fortio`, and the `drifter` on the `outpost` planet (no sidecar) |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies; every ship has its own service account except `fortio` and the `drifter` |
| `examples/01-identity/` | Identity-based guest lists for the probe and cargo, plus the `spiffe://` mistake in `cases/` |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | Two exam-style tasks with checked solutions |
