---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The notification service is about to be opened to a partner. The partner's users log in with an identity provider you do not control. All you get is the issuer's name and the address of its public keys. Make sure nothing reaches the service without a token that this issuer signed, and that a rejected partner can tell from the status code whether their token or your rules said no.

The namespace `jwt-demo` holds:

* `notification-service-v1`: answers `POST /notify`, behind the Service `notification-service` on port `80`. Its pods carry the label `app: notification-service`.
* `booking-service-v1`: the service next door, behind the Service `booking-service` on port `80`. It answers `POST /book`.
* `tester`: a client pod with `curl`. Send your test requests from here.

Istio 1.30.5 is installed, and every pod in `jwt-demo` has its sidecar. There is no `RequestAuthentication` and no `AuthorizationPolicy`.

Istio publishes a demo issuer you will use:

* **issuer:** `testing@secure.istio.io`
* **JWKS (the public keys):** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`
* **a valid token:** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt`

Protect `notification-service` so that:

1.  Tokens from the demo issuer are **checked** on `notification-service` only.
2.  A token is **required**: a request with no `Authorization` header is refused.
3.  From `tester`, `POST http://notification-service/notify` gives these results:

    | Request | Expected |
    | --- | --- |
    | no `Authorization` header | `403` |
    | `Authorization: Bearer invalid` | `401` |
    | `Authorization: Bearer <the demo token>` | `200` |

4.  `booking-service` stays reachable without a token (`POST http://booking-service/book` gives `200`).
5.  Both objects select `notification-service` with a `selector`. Do not make them cover the whole namespace.
6.  Leave the Deployments, Services and pod labels unchanged.

The two failure codes are different on purpose. If the bad token gets `403`, or the missing token gets `401`, something is wrong.

The cluster needs outbound internet: `istiod` downloads the public keys, and the grader downloads the demo token itself. The grader sends all three requests from `tester`, so the protection has to work, not merely exist.
