---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

Every logged-in user can reach the notification service, including its `/admin` path. The identity provider already puts group membership in the token. Use it, so that only administrators reach the `/admin` path.

The namespace `jwtclaims-demo` has sidecar injection on and runs:

* `notification-service-v1`: pods labelled `app: notification-service`, behind the `notification-service` Service on port `80`. It serves `POST /notify`. Any path it answers counts as "let through by the mesh"; only `403` means the mesh refused.
* `booking-service-v1`: another workload in the namespace. Leave it alone.
* `tester`: a client pod with `curl`. Send your test requests from here.

Istio 1.30.5 is installed. A `RequestAuthentication` named `jwt-demo` already checks tokens from the issuer `testing@secure.istio.io` on `notification-service`. Token checking is a starting point here, not the task. No `AuthorizationPolicy` exists.

Two sample tokens from the same issuer, with the same subject, are published at `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/`:

| Token | Claims |
| --- | --- |
| `demo.jwt` | no `groups` claim |
| `groups-scope.jwt` | `groups: ["group1", "group2"]` |

On `notification-service`, write authorization so that:

1.  **Any** request with a valid token may `POST /notify`.
2.  **Only** a token whose `groups` claim contains `group1` may `GET /admin`.
3.  A request with **no** token may do neither.
4.  Every rule that grants access requires a valid token (`requestPrincipals`), not only a claim.
5.  The `RequestAuthentication` named `jwt-demo` is **left unchanged**.

The grader fetches both tokens and sends these requests from `tester`:

| Request | Expected |
| --- | --- |
| no token, `POST /notify` | `403` |
| demo token, `POST /notify` | `200` |
| demo token, `GET /admin` | `403` |
| groups token, `GET /admin` | not `403` (the app answers) |
| no token, `GET /admin` | `403` |
