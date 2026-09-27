# Part 1 — Modes, and what they do to the inbound listener

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — The three scopes and how precedence resolves](./course-02-scopes-and-precedence.md).

`PeerAuthentication` has essentially one field. This part is about what that field does inside the receiving proxy, because the mechanism explains two things a table of modes cannot: why `PERMISSIVE` can accept both kinds of traffic on a single port, and why a `STRICT` rejection produces no HTTP status at all.

## `PERMISSIVE` is the default, and nothing declared it

With no `PeerAuthentication` anywhere, an Istio workload's inbound port accepts **both** mutual TLS and plaintext. That mode has a name — `PERMISSIVE` — even though no object in the cluster mentions it.

Concretely, in the playground right now: `tester` (meshed) reaches `notification-service` over mTLS, and `outside-client` (not meshed) reaches the same service over plain HTTP. Both get `200`. The traffic is encrypted in one case and not in the other, and nothing in the response tells them apart.

> [!TIP]
> **Try it — both callers succeed, for different reasons**
>
> ```sh
> kubectl -n mtls-demo get peerauthentication
> kubectl -n mtls-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'in-mesh: %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n outside exec deploy/outside-client -- \
>   curl -s -o /dev/null -w 'outside: %{http_code}\n' -X POST http://notification-service.mtls-demo/notify
> ```
>
> Expect something like:
>
> ```text
> No resources found in mtls-demo namespace.
> in-mesh: 200
> outside: 200
> ```
>
> Two successes and no policy object to explain them. `PERMISSIVE` is doing exactly its job here — and this is also the state a security review rejects, because "encrypted" is optional rather than required.

## The four modes

| Mode | The server's inbound port… |
| --- | --- |
| `PERMISSIVE` | accepts mTLS **and** plaintext. The default. |
| `STRICT` | accepts mTLS only. Plaintext connections are dropped. |
| `DISABLE` | does not use mTLS at all. |
| `UNSET` | inherits from the next wider scope. |

`UNSET` is worth a second look because it is what makes scoping composable, and it is not the same as "absent". A field left out entirely is `UNSET`; so is one written as `UNSET` explicitly. Either way the decision is deferred outward — to the namespace policy, then the mesh policy, then the built-in default of `PERMISSIVE`. That chain is [Part 2](./course-02-scopes-and-precedence.md)'s subject, and `UNSET` is the link that makes it a chain rather than a cliff.

`DISABLE` deserves one warning now: it is not "the opposite of `STRICT`" in any useful sense. It means the server will not do mTLS at all, so a meshed client that expects to send mTLS — which is the default — now has a mismatch to resolve. It exists for genuinely non-mesh-speaking ports, not as a way of relaxing security.

## How one port accepts two kinds of traffic

The interesting question about `PERMISSIVE` is mechanical: a TCP port is just a port. How does the same listener handle an incoming TLS handshake and an incoming plain HTTP request?

Envoy's answer is a **listener filter** that peeks at the first bytes of the connection before deciding how to process it, and then a set of **filter chains** it selects between:

```text
  connection arrives on the inbound port
              │
              ▼
   ┌────────────────────────┐
   │ tls_inspector          │  reads the first bytes without consuming them
   │ (a listener filter)    │  "does this look like a TLS ClientHello?"
   └───────┬────────────────┘
           │
    ┌──────┴────────┐
    │               │
   yes             no
    │               │
    ▼               ▼
 filter chain    filter chain
 match:          match:
 transport =     transport =
 "tls"           "raw_buffer"
    │               │
    ▼               ▼
 terminate mTLS,  treat as
 check cert       plaintext
    │               │
    └──────┬────────┘
           ▼
     HTTP filters, then the application container
```

Read the three modes off that diagram and they stop being arbitrary:

- **`PERMISSIVE`** programs *both* filter chains. Either branch has somewhere to go.
- **`STRICT`** programs only the `tls` chain. A plaintext connection matches nothing and is closed — before any bytes are parsed as a request, because the request was never reached.
- **`DISABLE`** programs only the `raw_buffer` chain.

That is the whole of it, and it is also why the reset happens where it does. There is no HTTP layer involved in a `STRICT` rejection: the connection is dropped at the transport, several layers below anything that could form a `403`.

## The failure signature

Applying `STRICT` is a one-object change, and the immediate observable is what the plaintext caller gets. It is worth seeing once, deliberately, so that you recognise it later when it is unintentional.

> [!TIP]
> **Try it — mesh-wide `STRICT`, and the plaintext caller's failure**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: PeerAuthentication
> metadata:
>   name: default
>   namespace: istio-system
> spec:
>   mtls:
>     mode: STRICT
> YAML
>
> kubectl -n mtls-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'in-mesh: %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n outside exec deploy/outside-client -- \
>   curl -s -o /dev/null -w 'outside: %{http_code}\n' --max-time 5 -X POST http://notification-service.mtls-demo/notify
> ```
>
> Expect something like:
>
> ```text
> in-mesh: 200
> outside: 000
> ```
>
> This changes mesh-wide state — it is the mesh-scope policy [Part 2](./course-02-scopes-and-precedence.md) builds on, so leave it in place if you are reading straight through, or undo it with `kubectl -n istio-system delete peerauthentication default`. The meshed caller is unaffected, because it was already using mTLS. The plaintext caller gets `000`, which is `curl`'s way of saying *no HTTP response at all*.

`000` is the signature to memorise, and the distinction it draws runs through the whole course:

```text
  403 + "RBAC: access denied"   the connection was accepted, the request parsed,
                                a policy refused it            → AuthorizationPolicy

  000 / connection reset        the transport was rejected; no request ever existed
                                → PeerAuthentication (or edge TLS, later)
```

Confusing the two sends you reading authorization policy when the problem is `PeerAuthentication`, or the reverse — and both searches can take a long time before anything contradicts you.

> *`PERMISSIVE` programs two filter chains and `STRICT` programs one, which is why a strict rejection is a dropped connection rather than a `403`.*

## Reference

- [PeerAuthentication reference](https://istio.io/latest/docs/reference/config/security/peer_authentication/) — the `mtls.mode` enum and the exact meaning of `UNSET`.
- [Istio mutual TLS concepts](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication) — the permissive-mode design and why it exists.
- [Envoy listener filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/tls_inspector) — what `tls_inspector` does with the first bytes of a connection.
