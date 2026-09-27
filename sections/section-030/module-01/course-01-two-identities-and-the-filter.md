# Part 1 — Two identities on one request

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — `RequestAuthentication` and the key set](./course-02-requestauthentication-and-jwks.md).

A single request can carry two independent claims about who is behind it: the workload making the call, and the person it is being made for. Istio keeps them on separate axes, with separate objects and confusingly similar field names. This part separates them, opens a token to see what is actually in one, and places the validating filter in the pipeline so the rest of the module has somewhere to hang.

## Peer identity and request identity

`PeerAuthentication` is about the calling **workload**. `RequestAuthentication` is about the calling **end user**. They are not alternatives: a request commonly carries both, a certificate proving *the frontend pod* is calling and a bearer token proving *Alice* is the person behind it.

| | Peer (workload) | Request (end user) |
| --- | --- | --- |
| Proved by | client certificate, mTLS | JWT in the `Authorization` header |
| Issued by | istiod's CA, automatically | an identity provider, outside the mesh |
| Configured by | `PeerAuthentication` | `RequestAuthentication` |
| Policy field | `principals` | `requestPrincipals` |
| Value shape | `<trust-domain>/ns/<ns>/sa/<sa>` | `<issuer>/<subject>` |
| Lifetime | ~24h, rotated silently | minutes to hours, reissued by login |
| Scope | this hop | end to end, forwarded across hops |

Both live in the `from.source` block of the same `AuthorizationPolicy` rule, so one rule can demand a specific workload **and** a valid end user:

```yaml
      from:
        - source:
            principals: ["cluster.local/ns/jwt-demo/sa/frontend"]
            requestPrincipals: ["*"]
```

The last row of the table is the one that explains why both exist. Peer identity is per hop: when the frontend calls the backend, the backend sees *the frontend's* certificate, not the browser's. The end user's token, by contrast, is forwarded along the chain, so a service three hops in can still know which user this work is for. Neither substitutes for the other.

## What is actually in a token

A JWT is three base64url-encoded sections joined by dots:

```text
   eyJhbGciOiJSUzI1NiIsImtpZCI6IkRIRmJwb0lVcXJZOHQy…  .  eyJleHAiOjQ2ODU5…  .  Xw1FHN…
   └──────────── header ────────────┘                    └─── payload ───┘     └ signature ┘
        alg: which algorithm                 the claims:              proves the payload
        kid: which key signed this           iss, sub, exp, aud,      was not altered and
                                             plus anything else       came from the issuer
```

Two properties matter for everything that follows.

**The payload is encoded, not encrypted.** Anyone holding the token can read every claim in it — which is why tokens carry assertions like "this user is in group1" and never carry secrets. Decoding one takes no key and no tooling beyond `base64`.

**The signature is what makes the claims worth anything.** A proxy verifying a token is checking that the payload was signed by a key belonging to the issuer, and has not expired. That is the entire security property: *the issuer said this*. Whether the issuer should have said it is the identity provider's problem, not the mesh's.

The `kid` in the header is how the proxy picks the right key from a set — relevant in [Part 2](./course-02-requestauthentication-and-jwks.md), where the set is fetched from the issuer.

## Where validation happens

The `jwt_authn` filter runs in the receiving workload's proxy, between HTTP parsing and authorization:

```text
   1. transport / mTLS          ← peer identity extracted here
        │
        ▼
   2. HTTP parsed               method, path, headers now exist
        │
        ▼
   3. jwt_authn filter          reads the Authorization header
        │                       ┌── no token    → pass through untouched
        │                       ├── bad token   → 401, stop
        │                       └── good token  → publish request.auth.* attributes
        ▼
   4. rbac filter               AuthorizationPolicy, which can now match on
        │                       principals (from 1) and requestPrincipals (from 3)
        ▼
   5. the application
```

Three things fall straight out of that ordering, and they are the whole of this module:

- **Stage 3 has no opinion about a missing token.** Its job is validation. A request with no `Authorization` header has nothing to validate, so it proceeds. That is [Part 2](./course-02-requestauthentication-and-jwks.md)'s surprise and [Part 3](./course-03-requiring-a-token.md)'s fix.
- **`401` and `403` come from different stages.** A bad token is rejected at 3; a refused decision is made at 4. Same request, two entirely different objects to go and look at.
- **Claims are attributes produced at stage 3 and consumed at stage 4.** The token's contents do not reach the application's policy by magic; stage 3 publishes them and stage 4 reads them. [Module 2](../module-02/course.md) is entirely about that hand-off.

## The starting state

Everything in this module is worth measuring against the state the playground begins in: a service with no security objects at all, where a token changes nothing because nothing is looking for one.

> [!TIP]
> **Try it — fetch the demo token and confirm the service is currently open**
>
> ```sh
> export TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
> echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
>
> kubectl -n jwt-demo get requestauthentication,authorizationpolicy
> kubectl -n jwt-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'no token: %{http_code}\n' -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> {"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
> No resources found in jwt-demo namespace.
> no token: 200
> ```
>
> The middle section decodes with no key, exactly as described above — `base64 -d` may complain about padding and still print the payload, which is why `2>/dev/null` is there. Note `iss` and `sub`: those two, joined by a slash, become the request principal in [Part 3](./course-03-requiring-a-token.md). `$TOKEN` now lives in your shell on the playground machine, which is why later commands can pass it with `-H`. An empty result means the machine has no outbound internet, and the rest of the module will not work.

> *Peer identity is per hop and proved by a certificate; request identity is end to end and proved by a signature — and the filter that checks the second one has no opinion about a request that carries none.*

## Reference

- [Istio authentication concepts](https://istio.io/latest/docs/concepts/security/#authentication) — peer versus request authentication, in Istio's own framing.
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519) — the three-section structure and the registered claims (`iss`, `sub`, `aud`, `exp`).
- [Envoy JWT authentication filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/jwt_authn_filter) — what stage 3 is, including how it publishes claims to later filters.
