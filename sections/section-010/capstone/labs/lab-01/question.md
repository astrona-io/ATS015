---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

Two requests reached you on the same day. The security team wants mutual TLS required across the whole mesh, with no exceptions. The booking team wants their notification service closed to every caller but one. There is a catch: one caller still runs outside the mesh. If you require mutual TLS before you deal with it, its requests fail.

A few words before you start:

* **Mutual TLS (mTLS)** means both sides of a connection present a certificate. The connection is encrypted, and both identities are verified.
* A **`PeerAuthentication`** sets whether a workload accepts plain text, mTLS or both on inbound connections. Its mode `STRICT` means "mTLS is required".
* An **`AuthorizationPolicy`** allows or denies requests to a workload, based on the caller, the operation and other conditions.
* A **principal** is the workload identity from the caller's certificate, without the `spiffe://` prefix, for example `cluster.local/ns/identity-demo/sa/booking-sa`.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. It has two namespaces.

**`identity-demo`** (sidecar injection on, so every pod gets a sidecar proxy (Envoy) that handles all its inbound and outbound traffic)

* `booking-service-v1`: runs with the service account `booking-sa`. Its Service `booking-service` listens on port `80`. When it gets a request, it calls `POST /notify` on `notification-service` and answers `200`, even if that onward call is refused.
* `notification-service-v1`: runs with the `default` service account. Its Service `notification-service` listens on port `80`.
* `tester`: a client pod with `curl`, running with the `default` service account.

**`outside`** (sidecar injection off)

* `outside-client`: a `curl` pod with **no sidecar** and no certificate. It calls `booking-service.identity-demo` in plain text.

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
