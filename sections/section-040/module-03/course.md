# TLS Passthrough Instead Of Termination

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-040/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-03/playground
> astrona destroy ats-015-playground-040-03
> ```

The previous two modules had the gateway decrypt the connection: it held the certificate, it saw the HTTP request, and it could route on paths and headers. Sometimes that is exactly what you must not do. A backend that has to prove its own identity end to end, a compliance requirement that no intermediary sees plaintext, a service that authenticates callers with their client certificate itself — all of these want the gateway to forward bytes and stay out of the way.

`mode: PASSTHROUGH` does that. The cost is everything the gateway could do *because* it decrypted, and the configuration changes shape accordingly: there is no HTTP to match on, so routing happens on the one field visible in an encrypted handshake.

## How this module is organised

1. **[Part 1 — What a proxy can see in a TLS stream](./course-01-what-a-proxy-can-see.md)** — the ClientHello, why SNI is readable when nothing else is, and the backend that owns its own certificate.
2. **[Part 2 — Configuring passthrough](./course-02-configuring-passthrough.md)** — `protocol: TLS` with `mode: PASSTHROUGH`, and the `VirtualService` `tls` block that routes on `sniHosts`.
3. **[Part 3 — What passthrough costs](./course-03-what-passthrough-costs.md)** — proving the gateway did not terminate, the complete list of what is unavailable, and choosing between the modes.

## Learning objectives

After this module you can:

- Say which parts of a TLS connection an intermediary can read without the key, and which it cannot.
- Explain why SNI exists and what reads it at the gateway.
- Configure a `Gateway` listener with `protocol: TLS` and `mode: PASSTHROUGH`.
- Route passthrough traffic with a `VirtualService` `tls` block matching on `sniHosts`.
- Explain why an `http` block cannot work for passthrough traffic, and recognise the failure it produces.
- Prove from the handshake, and from the absence of HTTP routes, which end terminated TLS.
- List what is given up at the edge, and choose between terminating and passthrough for a given requirement.

## Before you start

You need the ingress gateway basics from [Module 1](../module-01/course.md): a `Gateway` selects an edge proxy, a `VirtualService` binds to it, SNI selects the listener, and on `kind` you reach it through `port-forward`. Unlike the previous two modules, you need no certificate and no secret — the backend brings its own.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile, including `istio-ingressgateway` in `istio-system`), plus `istioctl` and `openssl`:

- **`passthrough-demo`** — injected. A `tls-backend` Deployment running nginx, which **generates its own self-signed certificate at startup** (CN `secure.ica.local`, O `backend`) and serves HTTPS on container port `8443`, fronted by a Service on `8443`.

No `Gateway` and no `VirtualService` exist yet.
