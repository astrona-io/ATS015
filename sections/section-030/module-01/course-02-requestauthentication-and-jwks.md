# Part 2 — `RequestAuthentication` and the key set

> Prerequisite: [Part 1 — Two identities on one request](./course-01-two-identities-and-the-filter.md). Next: [Part 3 — Requiring a token](./course-03-requiring-a-token.md).

This part configures stage 3. It is a short object with two load-bearing fields, and both of them fail in ways that produce the same unhelpful `401` — so understanding where the keys come from is worth more here than memorising the schema.

## The object

```yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-demo
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  jwtRules:
    - issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
```

`selector` and namespace scope it exactly like every other Istio security object — no selector means the whole namespace, and the root namespace means mesh-wide.

`jwtRules` is a list, which matters more than it looks: a workload can accept tokens from several issuers, and the proxy picks the rule whose `issuer` matches the token's `iss` claim. No matching rule means no way to validate, which is treated as a failure.

The fields inside one rule:

- **`issuer`** must equal the token's `iss` claim **exactly**. A string comparison, not URL normalisation — `https://auth.example.com` and `https://auth.example.com/` are different issuers as far as this check is concerned.
- **`jwksUri`** points at the issuer's public keys in JWKS (JSON Web Key Set) format.
- **`jwks`** is the inline alternative to `jwksUri` — the key set pasted into the object.
- **`audiences`** additionally requires the token's `aud` claim to contain one of these values. Omitted, `aud` is not checked, which is worth knowing: a token minted for a different service is otherwise perfectly acceptable.
- **`forwardOriginalToken`** keeps the `Authorization` header on the request as it goes to the application. Without it the header is stripped after validation.
- **`outputPayloadToHeader`** writes the decoded payload into a header of your choosing, for applications that want the claims without parsing the token themselves.

## How the keys actually arrive

The proxy needs the issuer's public key to check a signature. It does not ask the issuer per request — that would put an external dependency on every call. The path is:

```text
   you apply the RequestAuthentication
        │
        ▼
   istiod compiles it into a jwt_authn filter config
        │  the JWKS is resolved here or by the proxy,
        │  depending on version and configuration
        ▼
   key set is fetched over HTTPS  ──▶  cached
        │                                │
        │                          refreshed periodically
        ▼                                │
   every request: pick key by `kid`, verify signature, check exp/nbf, check iss
                  ── no network call ────┘
```

Three consequences, and each explains a real failure:

- **A slow or unreachable `jwksUri` fails a whole workload, not one request.** Every token gets `401`, including correct ones, because the proxy has no key to check against. The evidence is in the proxy and istiod logs — not in the application's, which never saw the request.
- **The failure appears *after* a clean apply.** The object is accepted, `kubectl get` lists it, and only traffic reveals that the key set never arrived. This is the same "accepted but not working" shape as a selector matching nothing.
- **Key rotation at the issuer is picked up on refresh, not instantly.** An issuer that rotates signing keys without publishing both for an overlap window will produce a burst of `401`s.

In an environment with restricted egress, the inline `jwks` field removes the dependency entirely: the keys live in the object, nothing is fetched, and nothing can be unreachable. The trade is that you now own rotating them.

## Validation has three outcomes

With the object in place and nothing else, stage 3 does one of three things:

```text
   Authorization header present?
        │
       no ──────────────▶  pass through untouched, no attributes published
        │
       yes
        ▼
   signature + exp + iss (+ aud, if configured) valid?
        │
       no ──────────────▶  401, request stops here
        │
       yes ─────────────▶  publish request.auth.principal, .claims[…], .audiences
                           and continue to stage 4
```

The first branch is the one to internalise, and it is not a bug: a `RequestAuthentication` on its own protects nothing, because the easiest way to avoid failing token validation is to not send a token.

> [!TIP]
> **Try it — validation is on, protection is not**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: RequestAuthentication
> metadata:
>   name: jwt-demo
>   namespace: jwt-demo
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   jwtRules:
>     - issuer: "testing@secure.istio.io"
>       jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
> YAML
>
> kubectl -n jwt-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'no token:  %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n jwt-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'bad token: %{http_code}\n' -H "Authorization: Bearer invalid" -X POST http://notification-service/notify
> kubectl -n jwt-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'valid:     %{http_code}\n' -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> no token:  200
> bad token: 401
> valid:     200
> ```
>
> Three requests, three branches of the diagram above. `bad token: 401` is the useful signal here — it proves the proxy fetched the key set and checked a signature, because a proxy with no keys could not have rejected anything specifically. And the service is no better protected than before: the tokenless call still returns `200`, so a caller who wants in simply omits the header.

## Why the issuer string is the usual culprit

When every token gets `401`, there are only three candidates, and they are worth checking in this order because that is roughly their frequency:

1. **`issuer` does not exactly match `iss`** — a trailing slash, `http` versus `https`, a copied value from a provider's documentation rather than from a real token. Decode a token and compare the strings character by character.
2. **The key set never arrived** — check the proxy and istiod logs for fetch errors, and confirm the cluster can reach the host at all.
3. **The token really is invalid** — expired, or signed by a key that is not in the set.

The first two are configuration and produce identical symptoms to the third, which is why "the token must be wrong" is such a common wrong turn. [Part 3](./course-03-requiring-a-token.md) ends with the command that reads the issuer back out of the proxy's own configuration, which settles candidate 1 in one line.

> *The proxy verifies a signature against a key set it fetched and cached, so an unreachable `jwksUri` rejects every token — including the correct ones — long after the object applied cleanly.*

## Reference

- [RequestAuthentication reference](https://istio.io/latest/docs/reference/config/security/request_authentication/) — `jwtRules` and every field described above.
- [JWT token authentication task](https://istio.io/latest/docs/tasks/security/authentication/jwt-route/) — Istio's own walkthrough, using the same demo issuer.
- [RFC 7517 — JSON Web Key](https://datatracker.ietf.org/doc/html/rfc7517) — what a JWKS document contains and how `kid` selects a key.
