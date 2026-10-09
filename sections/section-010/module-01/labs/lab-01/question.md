---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Your team runs a booking system. `booking-service` calls `notification-service` when a booking is confirmed, and that is the only call `notification-service` should receive. Right now any workload in the namespace can call it, including a debugging pod that someone left running. Make the restriction hold on something that cannot drift: the caller's mesh identity.

The namespace `identity-demo` has sidecar injection on and runs:

| Workload | Service account | What it does |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | Calls `notification-service`; container `booking-service`, port `8084` |
| `notification-service-v1` | `default` | Answers `POST /notify` behind the Service `notification-service` on port `80` |
| `tester` | `default` | A client pod with `curl`; container `tester` |

Istio 1.30.5 is installed. There is no `PeerAuthentication` and no `AuthorizationPolicy`, so every workload can call every other one.

In namespace `identity-demo`:

1.  Require **`STRICT`** mutual TLS for the **whole namespace** (a `PeerAuthentication` without a `selector`).
2.  Allow **only** `booking-service` to reach `notification-service`. Match on the caller's **mesh identity** in `principals`, not on its namespace, labels or address.
3.  Take the identity from the certificate `booking-service` really presents. Do not guess it.
4.  `booking-service` must get `200` from `POST http://notification-service/notify`, and `tester` must get `403` for the same call.
5.  Do not change any Deployment, Service or ServiceAccount. Solve this with Istio objects only. Object names are yours to choose.

The grader sends live requests from `booking-service` and `tester`, so the rules have to work, not merely exist.
