# Part 2 — The credential secret and the validation context

> Prerequisite: [Part 1 — Building the PKI](./course-01-building-the-pki.md). Next: [Part 3 — Handshake failures, and what a certificate proves](./course-03-handshake-failures-and-identity.md).

`MUTUAL` differs from `SIMPLE` by one word in the `Gateway` and one key in the secret. The key is the part that fails silently, so this part starts there.

## Two roles, one secret

Recall from [section 010](../../section-010/module-01/course-02-reading-the-certificate.md) that every mesh proxy holds two things: a certificate it presents, and a root it checks others against. Envoy's names for those roles are **tls_certificate** and **validation_context**, and the same pair reappears here — this time assembled by you, out of one Kubernetes secret:

```text
   Secret: booking-credential-mtls
   ┌──────────────────────────────────────────────┐
   │ tls.crt   the server certificate  ┐          │
   │ tls.key   its private key         ├─ what the gateway PRESENTS
   │                                   ┘  (tls_certificate)
   │                                              │
   │ ca.crt    the CA bundle           ── what the gateway CHECKS CLIENTS AGAINST
   │                                      (validation_context)
   └──────────────────────────────────────────────┘
```

For `SIMPLE`, only the first two exist and there is nothing to verify clients with. Adding `ca.crt` is what supplies the validation context — and therefore what makes `MUTUAL` mean anything.

The key names are fixed. `tls.crt`, `tls.key`, `ca.crt`, exactly. A secret with `cert`, `key` and `ca` applies cleanly, is listed by `kubectl get`, and delivers nothing the gateway recognises.

## Why `create secret tls` cannot build it

`kubectl create secret tls` accepts exactly a certificate and a key, produces a secret of type `kubernetes.io/tls`, and has no flag for a CA bundle. That is not an oversight — the Kubernetes TLS type is defined as that pair.

So the three-key secret is built with `create secret generic`, spelling out each key:

```sh
kubectl -n istio-system create secret generic booking-credential-mtls \
  --from-file=tls.crt=/tmp/booking.crt \
  --from-file=tls.key=/tmp/booking.key \
  --from-file=ca.crt=/tmp/ca.crt
```

The `key=path` form of `--from-file` is what makes this work: it sets the key *inside* the secret independently of the filename on disk. Without the `key=` prefix, `--from-file=/tmp/ca.crt` would create a key called `ca.crt` by luck of the filename — and `--from-file=/tmp/booking.crt` a key called `booking.crt`, which is wrong.

This produces the module's most dangerous failure, so it is worth naming precisely:

```text
   correct keys   → validation context delivered → MUTUAL enforced → clients checked
   wrong  keys    → no validation context        → the gateway still serves TLS
                                                 → clients NOT checked
                                                 → every request succeeds
```

The gateway does not refuse to start. It falls back to behaving like `SIMPLE`, which means **a successful request proves nothing about whether verification is on**. That asymmetry — wrong configuration producing *more* access rather than less — is why [Part 3](./course-03-handshake-failures-and-identity.md) insists on reading enforcement off the proxy.

There is a second supported layout worth recognising: the CA in its own secret named `<credentialName>-cacert`, alongside a normal `kubernetes.io/tls` secret for the server material. Both appear in Istio's documentation, and which one a given version prefers has changed over time. The single three-key secret is the simpler thing to reason about; prefer it unless something in your environment forces the split.

## Turning the mode on

```yaml
      tls:
        mode: MUTUAL
        credentialName: booking-credential-mtls
```

Everything else from [Module 1](../module-01/course-02-the-tls-listener.md) is unchanged: port `443`, `protocol: HTTPS`, a name starting `https`, `hosts` selecting by SNI, the secret in the gateway pod's namespace, a `VirtualService` bound to the gateway for anything to route to.

What changes in the handshake is one step:

```text
   SIMPLE                              MUTUAL
   ──────                              ──────
   ClientHello                         ClientHello
   server certificate  ──▶             server certificate  ──▶
                                       CertificateRequest  ──▶     ← the added step
                       ◀── client key                     ◀── client certificate
                                                           ◀── client key
   client verifies the server          client verifies the server
                                       server verifies the client   ← and the added check
   application data                    application data
```

The gateway sends a `CertificateRequest`, and the client answers it or does not. Both the request and the verification happen *inside* the handshake, before a single byte of HTTP exists — which is why [Part 3](./course-03-handshake-failures-and-identity.md)'s rejection has no status code.

> [!TIP]
> **Try it — create the three-key secret and require client certificates**
>
> ```sh
> kubectl -n istio-system create secret generic booking-credential-mtls \
>   --from-file=tls.crt=/tmp/booking.crt \
>   --from-file=tls.key=/tmp/booking.key \
>   --from-file=ca.crt=/tmp/ca.crt
> kubectl -n istio-system get secret booking-credential-mtls \
>   -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
>
> kubectl apply -f - <<'YAML'
> apiVersion: networking.istio.io/v1
> kind: Gateway
> metadata:
>   name: booking-gateway
>   namespace: mtlsedge-demo
> spec:
>   selector:
>     istio: ingressgateway
>   servers:
>     - port:
>         number: 443
>         name: https
>         protocol: HTTPS
>       hosts:
>         - booking.ica.local
>       tls:
>         mode: MUTUAL
>         credentialName: booking-credential-mtls
> ---
> apiVersion: networking.istio.io/v1
> kind: VirtualService
> metadata:
>   name: booking
>   namespace: mtlsedge-demo
> spec:
>   hosts:
>     - booking.ica.local
>   gateways:
>     - booking-gateway
>   http:
>     - match:
>         - uri:
>             prefix: /book
>       route:
>         - destination:
>             host: booking-service
>             port:
>               number: 80
> YAML
> ```
>
> Expect something like:
>
> ```text
> secret/booking-credential-mtls created
> ca.crt
> tls.crt
> tls.key
> gateway.networking.istio.io/booking-gateway created
> virtualservice.networking.istio.io/booking created
> ```
>
> Three keys, exactly those names. Check this **before** testing traffic: a secret with `cert`/`key`/`ca` instead produces the same "successful" apply, the same running gateway, and none of the behaviour — and a passing request would tell you nothing.

> *`ca.crt` is the validation context, and without it a `MUTUAL` gateway quietly degrades to `SIMPLE` — serving TLS, verifying nobody, and answering every request.*

## Reference

- [`ServerTLSSettings`](https://istio.io/latest/docs/reference/config/networking/gateway/#ServerTLSSettings) — `mode: MUTUAL`, `credentialName`, and the CA-related fields.
- [Secure gateways — mutual TLS](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/#configure-a-mutual-tls-ingress-gateway) — Istio's walkthrough, including the `-cacert` secret layout.
- [`kubectl create secret generic`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-em-secret-generic-em-) — the `--from-file=key=path` form that sets key names explicitly.
