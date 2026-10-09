---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

An auditor has a complaint about the namespace `authz-demo`. mTLS is on, so every caller's identity is checked. But nothing stops anyone: a debugging pod can call the notification service directly and skip the booking flow. You have been asked to close the namespace and reopen only the two calls the design needs.

Istio 1.30.5 is installed (`demo` profile). The namespace `authz-demo` has sidecar injection on, a `PeerAuthentication` in **`STRICT`** mode, and these workloads:

| Workload | Service account | Serves |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | `POST /book` (Service `booking-service`, port 80, container port 8084) |
| `notification-service-v1` | `default` | `POST /notify` (Service `notification-service`, port 80, container port 8084) |
| `tester` | `default` | a pod with `curl`; send your test calls from here |

No `AuthorizationPolicy` exists, so every call currently succeeds.

Using `AuthorizationPolicy` objects only, produce this end state in `authz-demo`:

1.  The namespace is **deny-by-default**: any workload for which nothing else is written is unreachable.
2.  `booking-service` accepts **`POST /book`** from any workload in the `authz-demo` namespace, and nothing else.
3.  `notification-service` accepts **`POST /notify`** from the **`booking-sa` identity only**, and nothing else. This rule must match on the caller's identity, not on its namespace.

The observable result:

| From | Call | Expected |
| --- | --- | --- |
| `tester` | `POST /book` on `booking-service` | `200` |
| `tester` | `GET /book` on `booking-service` | `403` |
| `tester` | `POST /notify` on `notification-service` | `403` |
| `booking-service` | `POST /notify` on `notification-service` | `200` |
| `booking-service` | `GET /notify` on `notification-service` | `403` |

Constraints:

* Do not change or remove the `PeerAuthentication`. Identity-based rules depend on it.
* Do not change the Deployments, their service accounts or the Services.

The grader sends all five calls above from the live pods and checks each status code. It also checks that a policy in `authz-demo` matches on `principals`, written without the `spiffe://` prefix.
