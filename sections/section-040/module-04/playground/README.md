# Originate TLS For External Services — Playground

- **Slug:** ats-015-playground-040-04
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with Istio and the `shuttle` client on the planet `starfleet`, then waits for you, astronaut. Use it alongside the module's parts. Nothing to submit.

**Needs outbound internet access.** The module calls `httpbin.org` on ports `80` and `443` from inside the cluster.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-040-04
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm, at the `ALLOW_ANY` default |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the `shuttle` client |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-egress-tls-origination/` | The `ServiceEntry` and `DestinationRule` for TLS origination to `httpbin.org`, plus the cases in `cases/` |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | An exam-style task with a checked solution |
