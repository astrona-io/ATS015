---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The security team has signed off on a rule: every workload in the mesh must use mTLS (mutual TLS, where both sides present a certificate). One team cannot comply yet. Their namespace still has a caller outside the mesh, so they get an exception for a few weeks. Their notification service is sensitive, and it does **not** get the exception, even though it runs in the same namespace.

The cluster has two namespaces:

* `mtls-demo`, with sidecar injection: `booking-service-v1` and `notification-service-v1` (both serve container port `8084`, behind Services on port `80`), and a client pod `tester`.
* `outside`, **without** sidecar injection: one pod `outside-client` with `curl` and no sidecar, so everything it sends is plain text.

Istio 1.30.5 is installed. No `PeerAuthentication` exists anywhere, so the default mode (`PERMISSIVE`) applies and both callers get answers today.

Using `PeerAuthentication` objects only, produce this end state:

1.  **Mesh-wide:** a `PeerAuthentication` named `default` makes `STRICT` the mode for the whole mesh.
2.  **Namespace exception:** a `PeerAuthentication` named `default` in `mtls-demo` sets the whole namespace back to `PERMISSIVE`.
3.  **Workload override:** a `PeerAuthentication` in `mtls-demo` makes `notification-service` `STRICT` again. `booking-service` must not be covered by it.

The result, checked with real requests:

| Caller | Call | Expected |
| --- | --- | --- |
| `outside-client` | `POST http://notification-service.mtls-demo/notify` | refused at the connection (`curl` prints `000`) |
| `outside-client` | `POST http://booking-service.mtls-demo/book` | `200` |
| `tester` | `POST http://notification-service/notify` | `200` |

Constraints:

* Do not change, add or delete any Deployment or Service.
* Do not add a sidecar to `outside-client`, and do not delete it. It is the only plain-text caller, and the grader needs it.
* Use `PeerAuthentication` only. No `AuthorizationPolicy`, no `DestinationRule`.

The grader checks that the policies exist at the right scopes, then sends live requests from `outside-client` and `tester`, so the result has to work, not merely exist.
