# Control Workload Certificates: Plug-In CA And Lifetime — Playground

- **Slug:** ats-015-playground-010-04
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio, deploys `shuttle` and `probe` in the namespace
`starfleet` with `STRICT` mutual TLS, and then waits. `istiod` runs with its default
self-signed certificate authority: no `cacerts` Secret exists. You create it while you
read. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-010-04
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet`, `shuttle`, `probe`, a `STRICT` `PeerAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-plug-in-ca/` | Reference files: `make-ca.sh` builds a root and an intermediate CA with `openssl` |
| `docs/overview.md` | What is in the box, helpers, things to try, practice tasks |

Status: UNTESTED. Built from the Istio documentation; nothing here has been run on a cluster.
