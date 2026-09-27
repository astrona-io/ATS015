# Overview: TLS Passthrough Instead Of Termination (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile — including the
  `istio-ingressgateway` Deployment in `istio-system` — plus `istioctl` and
  `openssl` on your PATH.
- One injected namespace, **`passthrough-demo`**:
  - `tls-backend` — nginx that generates its **own** self-signed certificate at
    startup (CN `secure.ica.local`, O `backend`) and serves HTTPS on container
    port `8443`, fronted by a Service on `8443`.
- **No `Gateway`, no `VirtualService`, and no secret in `istio-system`** — this
  module needs none. The certificate belongs to the backend.

> **No load balancer on `kind`.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Things to try

- Write the `VirtualService` with an `http` block instead of `tls` and watch the
  connection fail while every object reports as applied.
- Set `protocol: HTTPS` while keeping `mode: PASSTHROUGH` and see what the
  listener does.
- Make `hosts` and `sniHosts` disagree by one character.
- Connect without SNI (to `127.0.0.1` directly, no `--resolve`) and compare the
  failure with the mismatched-SNI one.
- Add a second backend on a second SNI host, sharing the same port `443`
  listener.
- Try to apply an `AuthorizationPolicy` with `paths:` against this traffic, then
  work out from first principles why it cannot fire.
- Compare `istioctl proxy-config routes` output for this host with a terminated
  listener you build alongside it.
- Look at the gateway access log for a passthrough connection versus a
  terminated one, and note what is missing.

## When you're done

```sh
astrona destroy ats-015-playground-040-03
```

(`astrona destroy` takes the environment name, not the config path.)
