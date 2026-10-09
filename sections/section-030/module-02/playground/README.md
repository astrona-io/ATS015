# Authorize On JWT Claims — Playground

- **Slug:** ats-015-playground-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A training solar system in the simulator: it starts a `kind` cluster with Istio
and the Starfleet (the Istio docs' Bookinfo sample, renamed), the `shuttle`
client and the `probe` echo service. The probe already checks end-user tokens
with a `RequestAuthentication`. Then it waits for you, astronaut. Use it
alongside the module's parts. Nothing to submit.

The playground needs outbound internet: `istiod` downloads the sample
issuer's public keys from GitHub, and you download the sample tokens.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-030-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, and the `probe-jwt` `RequestAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/03-jwt-claims/` | Claim rules on the probe: require a group, one rule per role, plus the cases in `cases/` (a claim no token has, a public path, a claim name typo) |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | Two exam-style tasks with checked solutions |
