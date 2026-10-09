---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The operations team wants the `probe` echo service in the namespace `starfleet` to become read-only. Today every workload in the namespace may send it anything, because of an `ALLOW` policy that another team owns. You may not touch that policy.

The namespace `starfleet` has sidecar injection on and a `PeerAuthentication` named `default` in `STRICT` mode. It holds:

* `probe-v1` and `probe-v2`: an echo service behind the Service `probe` on port `8000`. Its pods carry the label `app: probe`. `/get`, `/post`, `/delete` and `/anything` answer.
* `shuttle`: a client pod with `curl`, service account `shuttle`.
* `fortio`: a second client, service account `default`. It sends one request with `fortio load -quiet -n 1 <url>`, and a `POST` with `fortio load -quiet -n 1 -X POST <url>`. Add `2>&1 | grep -o "Code [0-9]*"` to see only the status code.

Istio 1.30.5 is installed, and every pod in `starfleet` has its sidecar. One `AuthorizationPolicy` already exists:

* `probe-allow-fleet` (`ALLOW`, selects `app: probe`): every workload in the namespace `starfleet` may send any request to the probe. **Leave it unchanged.**

Create a policy so that:

1.  An `AuthorizationPolicy` named `probe-read-only` exists in `starfleet`, with action `DENY`, and selects only the probe (`app: probe`).
2.  It refuses **every method except `GET`**, for **every** caller. Use one negative field, so methods you did not think of are covered too.
3.  `probe-allow-fleet` stays exactly as it is.
4.  Leave the Deployments, Services and the `PeerAuthentication` unchanged.

The result:

| Request | Expected |
| --- | --- |
| `GET http://probe:8000/get` from `shuttle` | `200` |
| `GET http://probe:8000/get` from `fortio` | `200` |
| `POST http://probe:8000/post` from `shuttle` | `403` |
| `POST http://probe:8000/post` from `fortio` | `403` |
| `DELETE http://probe:8000/delete` from `shuttle` | `403` |
| `PATCH http://probe:8000/anything` from `shuttle` | `403` |

The grader checks both policies, then sends these requests from `shuttle` and `fortio`, so the policy has to work, not merely exist.
