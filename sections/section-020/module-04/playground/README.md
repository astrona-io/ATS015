# External Authorization With CUSTOM Policies — Playground

- **Slug:** ats-015-playground-020-04
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio and the Starfleet, turns on `STRICT`
mutual TLS for the namespace `starfleet`, and deploys the Istio sample external
authorizer `ext-authz`. No extension provider is registered and no policy
exists: you do both while you read. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-020-04
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime and the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base` + `istiod`) with Helm |
| `bootstrap/deploy.sh` | Namespace `starfleet`, the Starfleet, `shuttle`, `probe`, `fortio`, `ext-authz`, the `drifter` on `outpost`, and a `STRICT` `PeerAuthentication` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies, including `ext-authz.yaml` |
| `examples/01-custom-policies/` | The authors' reference files: the `extensionProviders` block and a `CUSTOM` policy for the probe |
| `docs/overview.md` | What is in the box, helpers, things to try, practice tasks |

Status: UNTESTED. Built from the Istio documentation; nothing here has been run on a cluster.
