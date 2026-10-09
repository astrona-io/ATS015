# DENY Policies And Evaluation Order — Playground

- **Slug:** ats-015-playground-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio and the Starfleet (the Istio docs'
Bookinfo sample, renamed), turns on `STRICT` mutual TLS for the namespace
`starfleet`, then waits for you. Use it alongside the module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-020-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, `fortio`, the `drifter` on `outpost`, and a `STRICT` `PeerAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-deny-policies/` | The authors' reference policies: DENY a path, an ALLOW policy for the shuttle, plus the cases in `cases/` (DENY with `notMethods`, `rules: [{}]` as ALLOW and as DENY) |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | Two exam-style tasks with solutions |
