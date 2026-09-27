# Part 3 — Verifying, redirecting and rotating

> Prerequisite: [Part 2 — The TLS listener](./course-02-the-tls-listener.md). Next: [the module landing page](./course.md), then [Module 2 — Require Client Certificates At The Edge](../module-02/course.md).

A `200` proves the path works. It does not prove *which* certificate answered, which matters the moment a gateway serves more than one hostname. This part is the evidence, plus the two operational jobs that follow a working listener: sending plaintext callers to HTTPS, and replacing a certificate without an outage.

## Two ways to ask which certificate is served

They answer different questions and both are worth having.

**From the connection** — `curl -v` prints the certificate the server presented during the handshake. This is the client's view, and therefore the authoritative one: it is what a browser would see.

> [!TIP]
> **Try it — read the served certificate from the handshake**
>
> ```sh
> curl -sk -v --resolve booking.ica.local:8443:127.0.0.1 \
>   https://booking.ica.local:8443/book 2>&1 | grep -E 'subject:|issuer:|HTTP/'
> ```
>
> Expect something like:
>
> ```text
> * subject: CN=booking.ica.local; O=ica
> * issuer: CN=booking.ica.local; O=ica
> < HTTP/2 200
> ```
>
> Subject and issuer are identical because the certificate is self-signed. The subject `CN` is the one passed to `openssl` in [Part 1](./course-01-how-a-gateway-gets-its-certificate.md) — proof that this specific secret, and not some other listener or a default, answered the handshake. `HTTP/2` is ALPN doing its job: the client and gateway negotiated HTTP/2 during the TLS handshake.

**From the proxy** — the gateway's own view of what it holds and what it is listening for:

```sh
istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system --port 443
```

The same `proxy-config` family from [section 010](../../section-010/module-01/course-02-reading-the-certificate.md), pointed at the gateway Deployment instead of a workload. An **empty result from the first command is the signature of the namespace mistake**: the secret exists somewhere, the `Gateway` was accepted, and the credential was never delivered.

Use them together, in this order:

```text
   curl succeeds, right certificate      → done
   curl fails in the handshake           → proxy-config secret: is the credential there?
                                            no  → namespace / name / key-name problem
                                            yes → SNI: is the client sending the right name?
   curl succeeds, 404                    → TLS is fine; the VirtualService is the problem
   curl succeeds, wrong certificate      → SNI matched a different server block
```

## Redirecting HTTP to HTTPS

Serving HTTPS does not stop anyone calling port 80. A second server block handles that, and it needs no certificate:

```yaml
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - booking.ica.local
      tls:
        httpsRedirect: true
```

The `tls` block on an HTTP listener looks wrong at first glance — there is no TLS on port 80. `httpsRedirect` is the one field that belongs there, and the placement makes sense once you read `tls` as "this listener's relationship to TLS" rather than "this listener's TLS settings". Its relationship here is: insist on it.

The listener then answers `301` with a `Location` of the same URL on `https://`, and routes nothing. Note what that means for anything that is not a browser: a client that does not follow redirects sees a `301` and no body, which for an API caller is a failure rather than a redirect. `httpsRedirect` is right for human traffic and worth thinking about twice for machine traffic.

> [!TIP]
> **Try it — add the redirect and confirm port 80 no longer serves**
>
> ```sh
> kubectl -n tls-demo patch gateway booking-gateway --type json -p '[{
>   "op": "add", "path": "/spec/servers/-",
>   "value": {"port": {"number": 80, "name": "http", "protocol": "HTTP"},
>             "hosts": ["booking.ica.local"],
>             "tls": {"httpsRedirect": true}}}]'
>
> kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
> sleep 2
> curl -s -o /dev/null -w 'http: %{http_code}\n' -H "Host: booking.ica.local" http://localhost:8080/book
> ```
>
> Expect something like:
>
> ```text
> http: 301
> ```
>
> A second port-forward, so you now have two background jobs — `jobs` lists them and `kill %1 %2` stops both. Plain HTTP needs no `--resolve`, because there is no SNI involved: `-H "Host: …"` is enough. `301` rather than `200` is the whole point — the plaintext listener exists solely to tell callers to come back over TLS.

## Rotation is a secret update

Because credentials are delivered over SDS ([Part 1](./course-01-how-a-gateway-gets-its-certificate.md)), replacing the contents of `booking-credential` pushes the new certificate to the running gateway. No restart, no dropped connections, no `Gateway` change:

```text
   kubectl create secret tls booking-credential --key … --cert … \
     --dry-run=client -o yaml | kubectl -n istio-system apply -f -
        │
        ▼
   istiod notices the Secret change
        │
        ▼
   SDS push  ──▶  gateway Envoy swaps the certificate in memory
                  existing connections keep their negotiated session;
                  new handshakes get the new certificate
```

That is a genuine advantage over file-mounted certificates, and it is worth verifying once in the playground so you trust it under pressure — replace the secret with a certificate for a different `CN` and watch `curl -v` report the new subject within seconds.

The same property makes the expiry story manageable: an edge certificate from a public CA typically lives 90 days and is renewed by automation (`cert-manager` writing the same Secret, for instance), and the gateway picks each renewal up without anyone being involved.

Most of what goes wrong here produces a failure at the wrong layer to look useful.

> [!WARNING]
> **Common pitfalls**
>
> - **The secret in the application's namespace** — it must live where the gateway pod runs, normally `istio-system`. The listener never comes up and `proxy-config secret` shows nothing.
> - **A port name that does not start with `https`** — Istio uses the name prefix in deciding protocol handling, so the listener is not the one you meant to create.
> - **`create secret generic` with invented key names** — use `create secret tls`, or match the `tls.crt` / `tls.key` layout exactly.
> - **Testing without SNI** — the gateway selects a listener by SNI. Without `--resolve` (or real DNS) the handshake fails in a way that looks like a certificate problem.
> - **Confusing the SNI and `Host` selections** — a handshake failure is SNI; a `404` on a working TLS connection is the `VirtualService`.
> - **Expecting an `EXTERNAL-IP` on `kind`** — there is no load balancer. Use `port-forward`.
> - **`httpsRedirect` in front of API clients** — a `301` is only helpful to something that follows redirects.

## Two more listener settings

Both live in the same `tls` block and both are one-line changes worth knowing exist:

**`minProtocolVersion`** — `TLSV1_2`, `TLSV1_3`. Setting `TLSV1_3` is instructive precisely because of how it fails: older clients are rejected *during the handshake*, which looks exactly like the certificate problems above and is not one. `curl --tls-max 1.2` reproduces it on demand.

**`cipherSuites`** — restricts the negotiated ciphers, for environments with a policy that names them. Same failure shape: a client with no acceptable cipher fails in the handshake with no HTTP status.

Together with SNI mismatches and a missing credential, that makes four distinct causes of "the handshake failed" at an Istio gateway — which is why the verification order at the top of this part is worth following rather than guessing between them.

> *A credential arrives over SDS, so replacing the Secret rotates the certificate on a running gateway — and `curl -v` is the only view that tells you what a client actually received.*

## Reference

- [Secure gateways task](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/) — Istio's verification steps, including the HTTP-to-HTTPS redirect.
- [`ServerTLSSettings`](https://istio.io/latest/docs/reference/config/networking/gateway/#ServerTLSSettings) — `httpsRedirect`, `minProtocolVersion` and `cipherSuites`.
- [`istioctl proxy-config secret`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading what a gateway proxy currently holds.
