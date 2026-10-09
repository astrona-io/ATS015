# Authorization In Ambient Mode, L4 And L7 — Playground

- **Slug:** ats-015-playground-060-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A clean sandbox: it starts a `kind` cluster with Istio in **ambient mode** (no
sidecars) and the Starfleet example workloads (the Istio docs' Bookinfo sample,
renamed), then keeps running. Use it alongside the module's parts. Nothing to
submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-060-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs the Gateway API CRDs, then Istio 1.30.5 in ambient mode (`istio-base`, `istiod` with `profile=ambient`, `istio-cni`, `ztunnel`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet` enrolled in ambient mode, access logs, the Starfleet, `shuttle` client, `probe` v1/v2 |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-l4-policy/` | Identity and namespace rules that ztunnel enforces, plus the mistake case in `cases/` |
| `examples/02-waypoint-l7/` | The method rule for the waypoint and the waypoint `Gateway`, plus a variant in `cases/` |
| `docs/overview.md` | What is in the box, things to try |
| `docs/practice.md` | Two exam-style tasks with solutions |
