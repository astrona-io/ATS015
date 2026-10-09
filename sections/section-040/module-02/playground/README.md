# Require Client Certificates At The Edge — Playground

- **Slug:** ats-015-playground-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with Istio, an ingress gateway
and the Starfleet (the Istio docs' Bookinfo sample, renamed), then waits for you, astronaut. Use it
alongside the module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-040-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, port forwards to the ingress gateway (`8080` → `80`, `8443` → `443`), the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 with Helm: `istio-base` and `istiod` in `istio-system`, the ingress gateway in `istio-ingress` |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet and the `shuttle` client |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/` | The module's numbered YAML (`01-…`, `02-…`, `03-…`) |
| `examples/cases/` | The helper script for the "badge from another CA" case |
| `docs/overview.md` | What is in the box, how to make the certificates, the helper, things to try |
| `docs/practice.md` | An exam-style task with a solution |
