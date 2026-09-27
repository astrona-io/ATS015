# Part 1 — How a request gets authorized

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Default-deny and the allow-nothing policy](./course-02-default-deny-and-allow-nothing.md).

Before writing a single rule it is worth knowing where the decision is made and by what. Almost every confusing thing about `AuthorizationPolicy` — the default, the failure signature, why a caller cannot see why it was refused — follows from one fact: authorization runs in the **receiving** workload's proxy, as a filter, on a request that has already been accepted at the transport.

## The path a request takes

An inbound request passes through the sidecar in a fixed order. Authorization is one stage in it, and the stages before and after explain what it can and cannot see:

```text
   connection arrives at the receiving pod's sidecar
        │
        ▼
   1. transport                     PeerAuthentication decides here
      tls_inspector, filter chain   STRICT?  plaintext → connection dropped (000)
      mTLS terminated               ← peer identity extracted from the client cert
        │
        ▼
   2. HTTP is parsed                method, path, headers, host now exist
        │
        ▼
   3. jwt_authn filter              RequestAuthentication validates a token (section 030)
      → request.auth.* attributes   invalid token → 401
        │
        ▼
   4. rbac filter                   AuthorizationPolicy decides here
      inputs: peer identity, HTTP   no match → 403 "RBAC: access denied"
      attributes, token claims
        │
        ▼
   5. the application container
```

Three consequences fall out of that ordering, and all three are examinable:

- **Authorization only ever sees connections the transport already accepted.** A `STRICT` rejection happens at stage 1; no rule at stage 4 is consulted, because there is no request yet. That is why `000` and `403` point at different objects — the two decisions are made in different stages, by different mechanisms.
- **Peer identity arrives from stage 1, not from stage 4.** The `principals` field matches a value extracted from the client certificate during the mTLS handshake. Without mTLS there is no certificate, so there is no value, so the field cannot match — the subject of [Part 4](./course-04-identity-union-and-debugging.md).
- **Token claims arrive from stage 3.** Which is why `requestPrincipals` and `when` conditions on `request.auth.claims[...]` need a `RequestAuthentication` to have run first, and why they are a later section rather than this one.

## The RBAC filter

Stage 4 is Envoy's **RBAC filter** — role-based access control. It is not something you configure directly; istiod compiles it from the `AuthorizationPolicy` objects that select this workload:

```text
   AuthorizationPolicy objects          istiod                 the workload's Envoy
   ───────────────────────────          ──────                 ────────────────────
   selector matches these pods?  ──▶  collect all policies ──▶ envoy.filters.http.rbac
   action, rules                       for this workload        (+ a network-level
                                       compile to RBAC rules     rbac filter for
                                                                 non-HTTP ports)
```

Two practical facts follow.

**The `selector` decides membership, at compile time.** A policy whose selector matches no pod is a valid object that contributes to nothing. `kubectl get authorizationpolicy` shows it; the proxy has never heard of it. Telling those two states apart is the debugging move in [Part 4](./course-04-identity-union-and-debugging.md).

**The decision is local and stateless.** No call to istiod happens per request, and no shared state is consulted. The proxy holds compiled rules and evaluates them against the request in front of it. That is why a policy change takes effect within seconds of the push, and why it costs the request nothing measurable.

There is one caveat worth knowing rather than dwelling on: HTTP-level fields (`methods`, `paths`, `hosts`) are only available on ports Envoy is treating as HTTP. On a plain TCP port, only the connection-level fields — identity, namespace, IP, port — can be evaluated. The same distinction reappears, much more prominently, in ambient mode in [section 060](../../section-060/README.md).

## No policy means everything is allowed

Now the default, which is a consequence of the above rather than a separate rule. If no `AuthorizationPolicy` selects a workload, the RBAC filter has nothing to enforce, and every request that reaches stage 4 proceeds.

That is not a gap in the mesh. It is the mesh staying out of the way until asked — the same design choice as `PERMISSIVE` being the `PeerAuthentication` default.

> [!TIP]
> **Try it — the unrestricted starting point**
>
> ```sh
> kubectl -n authz-demo get authorizationpolicy
> kubectl -n authz-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'tester -> notification: %{http_code}\n' -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> No resources found in authz-demo namespace.
> tester -> notification: 200
> ```
>
> `tester` has no business calling `notification-service` directly — in the intended design only `booking-service` does — and nothing stops it. mTLS is on and strict, so the call was encrypted and the caller's identity was verified at stage 1. Neither fact was consulted, because no rule exists at stage 4 to consult it.

Hold onto that `200`. Everything in [Part 2](./course-02-default-deny-and-allow-nothing.md) is about the single object that turns it into a `403`.

## Where a denial is visible

One last consequence of "the decision happens on the receiving side": the caller learns almost nothing. It gets `403` and the body `RBAC: access denied`, with no indication of which policy fired or which rule it failed.

The evidence lives with the workload that refused:

- its **access log**, which records the request and the response code;
- its **proxy configuration**, which holds the compiled rules;
- `kubectl get authorizationpolicy -A`, which shows what could possibly be selecting it.

So the debugging shape for the rest of this section is: run the test `curl` from the caller, then look for the explanation on the callee. Looking for it on the caller is the most common way to waste twenty minutes here.

> *Authorization is a filter in the receiving proxy, after the transport and after HTTP parsing — which is why `000` and `403` are different objects' failures, and why the explanation is always on the callee.*

## Reference

- [Istio authorization concepts](https://istio.io/latest/docs/concepts/security/#authorization) — the architecture: where the engine runs and what it is given.
- [AuthorizationPolicy reference](https://istio.io/latest/docs/reference/config/security/authorization-policy/) — the object that compiles into the filter described here.
- [Envoy RBAC filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/rbac_filter) — what stage 4 actually is, including the HTTP versus network distinction.
