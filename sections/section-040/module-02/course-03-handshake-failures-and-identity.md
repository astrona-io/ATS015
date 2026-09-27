# Part 3 — Handshake failures, and what a certificate proves

> Prerequisite: [Part 2 — The credential secret and the validation context](./course-02-secret-and-validation-context.md). Next: [the module landing page](./course.md), then [Module 3 — TLS Passthrough Instead Of Termination](../module-03/course.md).

The gateway now demands a certificate. This part is what that looks like from both sides of a refused connection, how to prove enforcement is actually on — which a successful request cannot do — and what a verified certificate has and has not established.

## A rejection with no status code

> [!TIP]
> **Try it — with and without a client certificate**
>
> ```sh
> kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
> sleep 2
>
> curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
>   https://booking.ica.local:8443/book -o /dev/null -w 'no cert:   %{http_code}\n'
>
> curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
>   --cert /tmp/client.crt --key /tmp/client.key \
>   https://booking.ica.local:8443/book -o /dev/null -w 'with cert: %{http_code}\n'
> ```
>
> Expect something like:
>
> ```text
> curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required
> no cert:   000
> with cert: 200
> ```
>
> Stop the port-forward with `kill %1` when you are done. The first call fails **during the TLS handshake** — the exact error text varies with the client's OpenSSL version, but `certificate required` and a `000` status are the constants. No request was ever sent, so no route, no `VirtualService` and no authorization policy was involved. `--cert` and `--key` are what answer the `CertificateRequest` from [Part 2](./course-02-secret-and-validation-context.md)'s handshake diagram.

This is the same category of failure as a `STRICT` `PeerAuthentication` rejecting a plaintext caller in [section 010](../../section-010/module-02/course-01-modes-and-the-inbound-listener.md): the transport was refused, so there is nothing to return a status code on. By now the pattern is worth stating as a rule that spans the whole course:

```text
   000 / connection error   →  something refused the TRANSPORT
                               PeerAuthentication, edge TLS, SNI mismatch
   401 / 403                →  something refused the REQUEST
                               RequestAuthentication, AuthorizationPolicy
   404                      →  nothing refused anything; routing or the app
```

One important limit on what the client learns: a certificate from the **wrong CA** fails identically to no certificate at all. From the outside, "you sent nothing" and "you sent something I do not trust" are the same event. That is deliberate — a rejected client is told as little as possible — and it means the *server* side is where any diagnosis has to happen:

```sh
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=20
```

## Proving enforcement is on

[Part 2](./course-02-secret-and-validation-context.md) established the trap: a `MUTUAL` gateway with a missing or misnamed `ca.crt` serves TLS, verifies nobody, and answers every request. So **"my request succeeded" is not evidence that verification is enabled** — it is exactly what the broken configuration produces too.

The proxy's own configuration is the evidence.

> [!TIP]
> **Try it — read `requireClientCertificate` off the gateway listener**
>
> ```sh
> istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential-mtls
> istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system --port 443 -o json \
>   | grep -i requireClientCertificate
> ```
>
> Expect something like:
>
> ```text
> kubernetes://booking-credential-mtls     Cert Chain     ACTIVE     true ...
>     "requireClientCertificate": true,
> ```
>
> The same field you read in [section 010](../../section-010/module-02/course-03-proving-what-is-in-effect.md) to confirm a `STRICT` workload — the same Envoy property, reached from the other end of the mesh. `true` confirms the CA bundle was found and verification is enabled. **If the secret is listed but this says `false`, the `ca.crt` key is missing or misnamed** — which is the failure mode that lets unauthenticated clients through while everything looks configured.

That pairing is the whole verification procedure: the first command says the credential arrived, the second says what it was built into. Either one alone can mislead.

Most of what goes wrong in this module produces either no error or the wrong kind of success.

> [!WARNING]
> **Common pitfalls**
>
> - **`kubectl create secret tls` for `MUTUAL`** — it cannot carry a CA bundle, so client verification never turns on and the gateway happily accepts everyone.
> - **Wrong key names in the secret** — it must be exactly `tls.crt`, `tls.key`, `ca.crt`. Anything else fails silently and fails *open*.
> - **Concluding from a successful request that verification works** — that is also what the broken configuration does. Read `requireClientCertificate`.
> - **Expecting `403` for a rejected client** — the rejection is in the handshake. Expect a `curl` error and `000`.
> - **The secret in the application namespace** — same rule as `SIMPLE`: it belongs where the gateway pod runs.
> - **Assuming edge `MUTUAL` implies mesh mTLS** — they are unrelated. Check `PeerAuthentication` separately.
> - **Losing control of `ca.key`** — anyone holding it can mint a client the gateway will accept, indistinguishably from a legitimate one.
> - **Treating a verified client certificate as authorization** — it proves the CA signed this client, and nothing else.

## After verification: who is this client?

A verified client certificate answers one question: *was this signed by our CA?* If the CA issues certificates to five partners, all five pass, and the gateway has no further opinion about which of them is calling or what they may do.

Distinguishing them is a separate step, and there are two places to do it.

**At the application.** The gateway can forward the client certificate's details to the backend in the `X-Forwarded-Client-Cert` header (XFCC), which carries fields such as the subject and the SAN. An application that needs per-partner behaviour parses it. The header is only trustworthy because the gateway sets it after verifying — a backend reachable by any other path must not believe it.

**At the gateway.** An `AuthorizationPolicy` selecting the gateway pod can match on connection properties, which is exactly the shape [section 050](../../section-050/README.md) uses for source IP.

Either way the principle is the one from [section 020](../../section-020/module-01/course-01-how-a-request-is-authorized.md), restated at the edge: **authentication establishes who, authorization decides what.** `MUTUAL` mode only does the first — and it does it at the earliest possible moment, which is its real value. An unauthenticated client never gets to send a request at all, so nothing downstream spends a cycle on it.

That is also the honest comparison with the alternatives. A JWT ([section 030](../../section-030/README.md)) identifies an end user and can carry roles; a client certificate identifies a calling *system* and carries nothing but a name. They answer different questions, and an API serving partner systems on behalf of their users often wants both.

> *A rejected client learns nothing and a successful one proves nothing — `requireClientCertificate` on the listener is the only evidence that `MUTUAL` is actually enforcing.*

## Reference

- [Secure gateways — mutual TLS](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/#configure-a-mutual-tls-ingress-gateway) — Istio's testing steps, including the expected `curl` failure.
- [`istioctl proxy-config listener`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-listener) — reading `requireClientCertificate` and the rest of the listener.
- [X-Forwarded-Client-Cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert) — what the gateway can forward about a verified client, and its exact format.
