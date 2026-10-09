# Terminate TLS At The Ingress Gateway — Playground

- **Slug:** ats-015-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio, an ingress gateway and the Starfleet (the Istio docs'
Bookinfo sample, renamed), then waits for you. Use it alongside the module's parts. Nothing to
submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-040-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, port forwards to the ingress gateway (`8080` to `80`, `8443` to `443`), the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 with Helm: `istio-base` and `istiod` in `istio-system`, the ingress gateway in `istio-ingress` |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle` client |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/` | The module's numbered YAML (`01-…`, `02-…`) |
| `examples/cases/` | The YAML for the mistake cases |
| `docs/overview.md` | What is in the box, the test certificates, the helper, things to try |
| `docs/practice.md` | An exam-style task with a solution |
