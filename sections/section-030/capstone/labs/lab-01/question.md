---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

The notification service is opening to a partner's users. Their identity provider issues the tokens and writes user groups into them. You control none of that: you get only an issuer name and a key set address. No request may get in without a token from that issuer, and only one user group may call the admin path. A colleague set up token validation and called it done, and requests with no token at all still got straight through.

A few words before you start:

* A **JWT** (JSON Web Token) is a signed token that carries claims about the end user. The client sends it with each request, in the header `Authorization: Bearer <token>`.
* A **`RequestAuthentication`** validates a JWT if the request carries one. It does not require a token.
* The **JWKS** (JSON Web Key Set) is the set of public keys used to verify the token's signature.
* **Claims** are the fields inside the token, for example `iss` (who issued it) or `groups` (which user groups).
* An **`AuthorizationPolicy`** allows or denies requests to a workload. Its `requestPrincipals` field matches the request principal from a valid token (`<iss>/<sub>`).

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. The namespace `jwtclaims-demo` has sidecar injection on and runs:

* `booking-service-v1`: Service `booking-service` on port `80`, serves `POST /book`.
* `notification-service-v1`: Service `notification-service` on port `80`, serves `POST /notify` and has **no `/admin` handler**. An `/admin` request that gets through comes back `404` from the app. Anything that is not `403` means the mesh let it through.
* `tester`: a client pod with `curl`.

No `RequestAuthentication` and no `AuthorizationPolicy` exist yet. This lab needs outbound internet access, because the key set and the tokens are on `raw.githubusercontent.com`.

The demo issuer:

* **issuer:** `testing@secure.istio.io`
* **key set (JWKS):** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`
* **plain token** (no `groups` claim): `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt`
* **groups token** (`groups: ["group1","group2"]`): `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/groups-scope.jwt`

Both tokens have the same `iss` and `sub`, so they give the same request principal. Only their claims differ.

## Your task

On `notification-service`:

1. **Check** tokens from the demo issuer.
2. **Require** a token: a request with no `Authorization` header may do nothing.
3. **Split access by claim:** any valid token may `POST /notify`. Only a token whose `groups` claim contains `group1` may `GET /admin`.

The result, sent from `tester`, must be:

| Request | Expected |
| --- | --- |
| no token, `POST /notify` | `403` |
| `Authorization: Bearer invalid`, `POST /notify` | `401` |
| plain token, `POST /notify` | `200` |
| plain token, `GET /admin` | `403` |
| groups token, `GET /admin` | not `403` |
| no token, `GET /admin` | `403` |

## Rules

* Both rules must require a valid token (use `requestPrincipals`), not only test a claim.
* `booking-service` must stay reachable without a token: `POST /book` from `tester` still returns `200`.

The grader checks that a `RequestAuthentication` names the issuer, that a rule uses `requestPrincipals` and a `request.auth.claims[...]` condition, and then sends all six requests plus one to `booking-service`.
