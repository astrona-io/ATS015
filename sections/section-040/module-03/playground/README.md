# TLS Passthrough Instead Of Termination — Playground

- **Slug:** ats-015-playground-040-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with Istio, an ingress gateway,
the Starfleet (the Istio docs' Bookinfo sample, renamed) and the vault (`tls-backend`, a ship that
ends TLS itself with its own certificate), then waits for you, astronaut. Use it alongside the
module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-040-03
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, port forwards to the gateway's ports `80` (`127.0.0.1:8080`) and `443` (`127.0.0.1:8443`), the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 with Helm: `istio-base` and `istiod` in `istio-system`, the ingress gateway in `istio-ingress` |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, the `shuttle` client, the vault (`tls-backend`), and the bridge behind the gate over HTTP |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/` | The module's numbered YAML (`01-…`, `02-…`, `03-…`) |
| `examples/cases/` | The YAML for each mistake case in the overview |
| `docs/overview.md` | What is in the box, the helpers, things to try |
| `docs/practice.md` | An exam-style task with a solution |
