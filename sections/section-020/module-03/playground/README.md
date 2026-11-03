# Authorize TCP Traffic — Playground

- **Slug:** ats-015-playground-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio and the Starfleet, turns on `STRICT`
mutual TLS for the namespace `starfleet`, and adds `tcp-echo`, a plain TCP
server on ports 9000, 9001 and 9002, and two TCP clients, `shuttle` and
`relay`. Use it alongside the module's parts. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-020-03
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet`, the Starfleet, `shuttle`, `relay`, `tcp-echo`, `probe`, `fortio`, the `drifter` on `outpost`, and a `STRICT` `PeerAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies, including `tcp-echo.yaml` and `relay.yaml` |
| `examples/01-tcp-policies/` | The authors' reference policies: ALLOW by port, ALLOW by identity, and the cases in `cases/` (HTTP-only fields in ALLOW and DENY rules) |
| `docs/overview.md` | What is in the box, helpers, things to try, practice tasks |

Status: UNTESTED. Built from the Istio documentation; nothing here has been run on a cluster.
