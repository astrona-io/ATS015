# Authorize By Source IP At The Ingress Gateway — Playground

- **Slug:** ats-015-playground-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

It starts a `kind` cluster with Istio, an ingress gateway (the Envoy proxy
that accepts traffic from outside the cluster) and the Starfleet sample app
(the Istio docs' Bookinfo sample, renamed). The gateway already answers for
`starfleet.example.com`. Use it alongside the module's parts. Nothing to
submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-050-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the configuration
path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition: kind runtime, port forwards to the gateway (`127.0.0.1:8080` and `127.0.0.1:8443`), the two bootstrap scripts |
| `bootstrap/install-istio.sh` | Installs Istio 1.30.5 (`istio-base`, `istiod`, ingress gateway `istio-ingress`) with Helm. `numTrustedProxies` is left unset |
| `bootstrap/deploy.sh` | Namespace `starfleet` with injection, access logs, the Starfleet, `shuttle`, `probe` v1/v2, the `Gateway` and `VirtualService` for `starfleet.example.com` |
| `bootstrap/manifests/` | The YAML `deploy.sh` applies |
| `examples/01-guard-the-gate/` | A policy on the gateway pod, plus the wrong-namespace and wrong-selector cases |
| `examples/02-ip-blocks/` | `ipBlocks` (the connection peer) behind the port forward |
| `examples/03-trusted-proxies/` | Helm values that set `numTrustedProxies`, mesh-wide or for one gateway |
| `examples/04-remote-ip-blocks/` | Block a client range with `remoteIpBlocks` |
| `examples/05-one-path-one-network/` | One path open to one network only, and the `ALLOW` mistake |
| `examples/06-https/` | An HTTPS server on the gateway, to see that a gateway policy covers it too |
| `docs/overview.md` | What is in the box, helpers, things to try |
| `docs/practice.md` | Exam-style tasks with solutions |
