# Enforce mTLS With PeerAuthentication At Three Scopes — Playground

- **Slug:** ats-015-playground-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with
Istio, the Starfleet (the Istio docs' Bookinfo sample, renamed) and one ship
with no sidecar, then waits for you, astronaut. Use it alongside the module's
parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-010-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the
configuration path. `astrona submit` and `astrona test` do not apply: there is
no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, and namespace `outpost` with the `drifter` (no sidecar) |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-mtls/` | `PeerAuthentication` at namespace, workload and mesh scope, a client-side `DestinationRule`, plus the cases in `cases/` |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | Exam-style tasks with checked solutions |
