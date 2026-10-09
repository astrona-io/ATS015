---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

Astronaut, the notification service has an admin area that was never meant to be reachable from inside the cluster. It will be removed next quarter. Until then it must stay shut, and it must **stay** shut when someone who never heard of this mission adds a generous `ALLOW` rule later. To prove that, you write that careless `ALLOW` yourself and leave it in place.

The namespace `deny-demo` has sidecar injection on and a `PeerAuthentication` in `STRICT` mode. It runs:

* `notification-service-v1`: the pods behind the Service `notification-service` on port `80`, with the label `app: notification-service`. The app answers `200` on every path, so a `403` can only come from the mesh.
* `booking-service-v1`: another workload, service account `booking-sa`.
* `tester`: a client pod with `curl`. Send your test requests from here.

Istio 1.30.5 is installed, and every pod in `deny-demo` has its sidecar. No `AuthorizationPolicy` exists yet.

On `notification-service`, in the namespace `deny-demo`:

1.  **Allow** `POST /notify` from any workload in the `deny-demo` namespace.
2.  **Deny** every request whose path is `/admin` **or anything beneath it**, from every caller.
3.  Also create an `ALLOW` policy that explicitly permits the `/admin` path on the same workload, and **leave it in place**.

Requirement 3 is on purpose. In the end state, `/admin` must still be refused even though a policy explicitly allows it. If your configuration lets `/admin` through, you have the evaluation order wrong.

The result, with every request sent from `tester`:

| Request | Expected |
| --- | --- |
| `POST http://notification-service/notify` | `200` |
| `GET http://notification-service/admin` | `403` |
| `GET http://notification-service/admin/users` | `403` |

Constraints:

* Do not delete the `ALLOW` policy from requirement 3 to make the test pass.
* Do not solve requirement 2 by removing the `/notify` allowance.
* Leave the Deployments, Services and the `PeerAuthentication` unchanged.

The grader checks that a `DENY` policy exists and that an `ALLOW` policy naming an `/admin` path exists. Then it sends the three requests above from `tester`, so the policies have to work, not merely exist.
