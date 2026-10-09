---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

Astronaut, the notification service is opening to a partner's crew. Their identity provider issues the boarding passes and writes crew groups on them. You control none of that: you get only an issuer name and a key set address. Nobody may get in without a pass from that issuer, and only one crew group may use the admin door. A colleague set up the pass checker and called it done, and signals with no pass at all still flew straight through.

A few words before you start:

* A **JWT** (JSON Web Token) is a signed boarding pass an astronaut carries with every signal, in the header `Authorization: Bearer <token>`.
* A **`RequestAuthentication`** is the pass checker. It checks any pass that is shown, but it does not demand one.
* The **JWKS** (JSON Web Key Set) is the list of official stamps the pass checker compares passes against.
* **Claims** are the lines printed on the pass, for example `iss` (who issued it) or `groups` (which crew groups).
* An **`AuthorizationPolicy`** is the guard's list at the airlock. `requestPrincipals` is the name on the boarding pass.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. The planet `jwtclaims-demo` has sidecar injection on and runs:

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
