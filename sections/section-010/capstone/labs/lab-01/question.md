---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

Astronaut, two orders reached you on the same day. Security wants the secret handshake required across the whole fleet, with no exceptions. The booking team wants their notification service closed to every ship but one. There is a catch: one caller still flies outside the mesh, and if you turn on the first order before you deal with it, it loses contact.

A few words before you start:

* **Mutual TLS (mTLS)** is a secret handshake. Both ships show their ID badges (certificates) before they talk.
* A **`PeerAuthentication`** is the rule on a ship's airlock. Its mode `STRICT` means "the handshake is required".
* An **`AuthorizationPolicy`** is the guard's list at the airlock. It says who may come aboard.
* A **principal** is the name printed on a ship's ID badge, for example `cluster.local/ns/identity-demo/sa/booking-sa`.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. It has two planets (namespaces).

**`identity-demo`** (sidecar injection on, so every ship has a communications officer)

* `booking-service-v1`: runs with the service account `booking-sa`. Its Service `booking-service` listens on port `80`. When it gets a request, it calls `POST /notify` on `notification-service` and answers `200`, even if that onward call is refused.
* `notification-service-v1`: runs with the `default` service account. Its Service `notification-service` listens on port `80`.
* `tester`: a client pod with `curl`, running with the `default` service account.

**`outside`** (sidecar injection off)

* `outside-client`: a `curl` pod with **no sidecar** and no ID badge. It calls `booking-service.identity-demo` in plain text.

No `PeerAuthentication` and no `AuthorizationPolicy` exist yet.

## Your task

1. **Mesh-wide STRICT.** Create a `PeerAuthentication` named `default` that makes `STRICT` the rule for the **whole mesh**. Put it where the mesh scope lives: the root namespace `istio-system`, with no `selector`. A policy in `identity-demo` is only a namespace policy and does not count.
2. **No caller left behind.** `outside-client` must end up inside the mesh, with a sidecar, and must still reach `booking-service`. Do this **before** step 1 takes effect for it, or its calls fail.
3. **Authorize on identity.** `notification-service` accepts requests only from the `booking-sa` identity. Match on `principals`, not on namespaces, labels or addresses. Read the identity from the certificate the workload actually holds, and write it without the `spiffe://` prefix.

The result must be:

| From | Call | Expected |
| --- | --- | --- |
| `booking-service` | `POST /notify` on `notification-service` | `200` |
| `tester` | `POST /notify` on `notification-service` | `403` |
| `outside-client` | `POST /book` on `booking-service.identity-demo` | `200` |

## Leave alone

* Do not delete `outside-client`, and do not move it to another namespace.

The grader checks the mesh-wide policy, checks that `outside-client` has a sidecar, sends all three calls, and reads your `AuthorizationPolicy` to check that it matches on `principals`.
