# Authenticate End Users With JWT — Playground

- **Slug:** ats-015-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A clean environment: it starts a `kind` cluster with Istio and the Starfleet
sample app (the Istio docs' Bookinfo sample, renamed), then waits for you.
Use it alongside the module's parts. Nothing to submit.

The cluster needs outbound internet. `istiod` downloads the sample signing keys
from `raw.githubusercontent.com`, and you download the sample token from there
too.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle` client, `probe` v1/v2 |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-require-a-token/` | Check tokens on the probe and require one, plus the cases in `cases/` (token in a query parameter, "token required" written as `DENY`) |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/overview.md` (end) | Exam-style practice tasks with solutions, now part of the guide |
