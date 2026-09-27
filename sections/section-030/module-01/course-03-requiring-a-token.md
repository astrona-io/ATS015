# Part 3 — Requiring a token

> Prerequisite: [Part 2 — `RequestAuthentication` and the key set](./course-02-requestauthentication-and-jwks.md). Next: [the module landing page](./course.md), then [Module 2 — Authorize On JWT Claims](../module-02/course.md).

Validation is on and the service is still open to anyone who omits the header. This part closes it, with an object from a different API group than you might expect — and then makes the two failure codes tell you which half of the setup to go and look at.

## The requirement is an authorization decision

"Every request must carry a valid token" is a statement about what is *permitted*, not about how a token is checked. Istio puts it where such statements live:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
```

The **request principal** is `<issuer>/<subject>` — built from the token's `iss` and `sub` claims, joined by a slash. For the Istio demo token from [Part 1](./course-01-two-identities-and-the-filter.md), where both claims are `testing@secure.istio.io`, that is `testing@secure.istio.io/testing@secure.istio.io`. `["*"]` means "any request principal", which reads as *any valid token, whoever it belongs to*.

The mechanism is [section 020](../../section-020/module-01/course-02-default-deny-and-allow-nothing.md)'s, unchanged: this is an `ALLOW` policy selecting `notification-service`, so everything it does not permit is now denied. Trace one tokenless request through the pipeline and the result is forced:

```text
   no Authorization header
        │
   stage 3: nothing to validate, passes through, publishes no attributes
        │
   stage 4: an ALLOW policy selects this workload → the request must match a rule
            the only rule needs a requestPrincipal
            there is no requestPrincipal
        │
        ▼
   403
```

No new mechanism was introduced to require a token. The requirement is an emergent property of default-deny plus a rule that only a token can satisfy.

Narrowing from `["*"]` to an exact principal restricts *which* user, not merely that one exists:

```yaml
            requestPrincipals: ["testing@secure.istio.io/alice"]
```

and the wildcard form `testing@secure.istio.io/*` accepts any subject from that one issuer — useful when a workload trusts several issuers but only wants users from one of them on a particular path.

> [!TIP]
> **Try it — now the tokenless call is refused**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: require-jwt
>   namespace: jwt-demo
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             requestPrincipals: ["*"]
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
> no token:  403
> bad token: 401
> valid:     200
> ```
>
> The same three requests as [Part 2](./course-02-requestauthentication-and-jwks.md), with the first one changed by the new policy. Two different failures, from two different stages, produced by two different objects.

## 401 and 403 point at different halves

```text
   401   stage 3   RequestAuthentication rejected the token
                   → the token, the issuer string, or the key set
                   → the request never reached authorization

   403   stage 4   AuthorizationPolicy refused the request
                   → the token was fine, or absent, and the RULE said no
                   → validation is working; the policy is the thing to read
```

Reading `403` as "the token must be wrong" is the classic wrong turn, and it sends you editing `jwtRules` when the problem is a `requestPrincipals` value or a selector. The codes are a routing hint, and taking them literally saves most of the time this module's failures cost.

One more distinction to keep from earlier sections: neither of these is `000`. A connection reset is the transport, which means `PeerAuthentication` or edge TLS, and no amount of token work will touch it.

## Confirming the filter reached the proxy

Both `401`-shaped problems — a wrong `issuer` and a missing key set — are invisible in `kubectl get`. The proxy's compiled configuration shows what was actually built.

> [!TIP]
> **Try it — find the JWT filter and the issuer it was built with**
>
> ```sh
> istioctl proxy-config listener deploy/notification-service-v1 -n jwt-demo -o json \
>   | grep -i 'jwt_authn\|issuer' | head
> istioctl analyze -n jwt-demo
> ```
>
> Expect something like:
>
> ```text
>                     "name": "envoy.filters.http.jwt_authn",
>                                 "issuer": "testing@secure.istio.io",
> ✔ No validation issues found when analyzing namespace: jwt-demo.
> ```
>
> The `issuer` string here is the exact value being compared against `iss`, so reading it is the fastest way to catch a typo or a stray trailing slash — you are comparing two strings you can both see, rather than one you can see and one you assumed. An absent filter means the `RequestAuthentication` selected no pod. `istioctl analyze` is worth running after any security change; it catches the typo-class mistakes that otherwise present as mysterious `401`s.

Most of what goes wrong in this module is one of two objects being asked to do the other's job.

> [!WARNING]
> **Common pitfalls**
>
> - **Believing `RequestAuthentication` protects a workload** — without a `requestPrincipals` policy, tokenless requests pass straight through with `200`.
> - **An `issuer` that does not match `iss` exactly** — including a trailing slash or a scheme difference. Every token gets `401` and the message does not say why.
> - **An unreachable `jwksUri`** — the proxy cannot fetch keys, so every token fails. The evidence is in the proxy and istiod logs, not the application's.
> - **Reading `403` as a token problem** — it is the opposite: authorization refused a request that passed, or skipped, validation.
> - **Confusing `principals` with `requestPrincipals`** — one is the workload's certificate identity, the other the end user's token identity. Both sit in `from.source`.
> - **Omitting `audiences` and assuming `aud` is checked** — it is not, unless you list them. A token minted for another service will validate.
> - **Expecting the application to see the token** — the `Authorization` header is stripped after validation unless `forwardOriginalToken` is set.

## Operational notes

**Istio validates; it does not issue.** Something else — an identity provider, an API gateway, your own login service — mints tokens and gets them into the `Authorization` header. Nothing in this module changes what a client sends, and there is no Istio object that creates a token.

**Key fetching is a startup and refresh dependency, not a per-request one.** Covered in [Part 2](./course-02-requestauthentication-and-jwks.md), and worth restating because it shapes where you look: a JWKS problem degrades a whole workload at once, which looks like an outage rather than an authentication bug.

**Validation is not authorization.** A valid token means "this request carries an identity the issuer vouched for". It says nothing about whether that user may call *this* endpoint. Matching on what the token actually claims — roles, groups, a specific subject — is [Module 2](../module-02/course.md).

> *Requiring a token is not a feature of `RequestAuthentication`; it is default-deny plus a rule that only a request principal can satisfy.*

## Reference

- [AuthorizationPolicy `Source`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `requestPrincipals`, including the `*` and `<issuer>/*` forms.
- [JWT token authentication task](https://istio.io/latest/docs/tasks/security/authentication/jwt-route/) — Istio's own require-a-token walkthrough.
- [`istioctl analyze`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-analyze) — the static checks that catch selector and reference mistakes before traffic does.
