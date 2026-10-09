# Authorize HTTP Traffic Between Workloads — Playground

- **Slug:** ats-015-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio, the Starfleet (the Istio docs'
Bookinfo sample, renamed) and `STRICT` mTLS in the namespace `starfleet`,
then waits for you. Use it
alongside the module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-020-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the
configuration path. `astrona submit` and `astrona test` do not apply: there
is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, port forward to the bridge, the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection and access logs, the Starfleet, `shuttle`, `probe` v1/v2, `fortio`, the `outpost` namespace with the `drifter`, and the `STRICT` `PeerAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-allow-policies/` | Allow-nothing, "only the shuttle may GET the probe", least privilege for every Starfleet workload, plus the cases in `cases/` (a whole namespace, `rules: [{}]`, a selector typo) |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/overview.md` (end) | Exam-style practice tasks with solutions, now part of the guide |
