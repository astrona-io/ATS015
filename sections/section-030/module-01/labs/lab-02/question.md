---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

An old ground station wants to call the probe. It cannot set an `Authorization` header; it can only add the token to the URL, as `?token=...`. The operations team wants the probe to accept tokens from that place only, and to refuse every request without a valid token. Other teams will add their own `ALLOW` policies to the probe later, so "token required" must not change what those policies allow: write it as a `DENY` policy.

The namespace `starfleet` holds:

* `probe-v1` and `probe-v2`: an echo service behind one Service `probe` on port `8000`. Its pods carry the label `app: probe`. `/headers` sends back the headers it received.
* `shuttle`: a client pod with `curl`. Send your test requests from here.

Istio 1.30.5 is installed, and every pod in `starfleet` has its sidecar. There is no `RequestAuthentication` and no `AuthorizationPolicy`.

Use Istio's demo issuer:

* **issuer:** `testing@secure.istio.io`
* **JWKS (the public keys):** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`
* **a valid token:** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt`

Do the following in namespace `starfleet`:

1.  Create a `RequestAuthentication` named `probe-jwt` that selects the pods with `app: probe`, checks tokens from the demo issuer, and reads the token **only** from the query parameter `token`.
2.  Create an `AuthorizationPolicy` named `probe-require-jwt` that selects the pods with `app: probe` and, with `action: DENY`, refuses every request that has no valid request principal.
3.  Do not create any `ALLOW` `AuthorizationPolicy`.
4.  From `shuttle`, requests to `http://probe:8000/headers` give these results:

    | Request | Expected |
    | --- | --- |
    | `?token=<the demo token>` | `200` |
    | header `Authorization: Bearer <the demo token>`, no query parameter | `403` |
    | `?token=bad` | `401` |
    | no token at all | `403` |

5.  Leave the Deployments, Services and pod labels unchanged.

The cluster needs outbound internet: `istiod` downloads the public keys, and the grader downloads the demo token itself. The grader reads both objects and sends all four requests from `shuttle`, so the rules have to work, not merely exist.
