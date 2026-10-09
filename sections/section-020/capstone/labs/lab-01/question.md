---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

You are writing the access rules for a namespace that has none. Two calls are allowed, and everything else is not. One path, the admin path on the notification service, must stay blocked no matter what anyone adds to the rules later. A colleague says a future `ALLOW` policy could always reopen it. Your job is to prove them wrong.

A few words before you start:

* An **`AuthorizationPolicy`** allows or denies requests to a workload. Its action `ALLOW` lists the requests that may pass, and `DENY` lists the requests that are blocked.
* Once any `ALLOW` policy selects a workload, every request that no `ALLOW` rule matches is denied. This is **default-deny**.
* The sidecar proxy always checks `DENY` policies before `ALLOW` policies.
* A **principal** is the workload identity from the caller's certificate, without the `spiffe://` prefix, for example `cluster.local/ns/authz-demo/sa/booking-sa`.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. The namespace `authz-demo` has sidecar injection on, and a `STRICT` `PeerAuthentication` already requires mutual TLS (mTLS) there. With mTLS, both sides present a certificate, so the caller's identity can be trusted.

| Workload | Service account | Serves |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | Service `booking-service` on port `80`, `POST /book` |
| `notification-service-v1` | `default` | Service `notification-service` on port `80`, `POST /notify`, and **no `/admin` handler** |
| `tester` | `default` | a client pod with `curl` |

No `AuthorizationPolicy` exists yet.

`notification-service` has no `/admin` handler. So an `/admin` request that is **not** blocked comes back `404` from the app. That is how you tell "a policy denied it" (`403`) from "it reached the app" (`404`).

## Your task

In the namespace `authz-demo`:

1. **Deny by default.** A workload that nobody has written a rule for must be unreachable.
2. **Reopen exactly two calls.**
   * `POST /book` on `booking-service`, from anything in the namespace.
   * `POST /notify` on `notification-service`, from the **`booking-sa` identity only**. Match it with `principals`, without the `spiffe://` prefix.
3. **Add a backstop.** Deny every request to `notification-service` whose path is `/admin` **or anything below it**. It must stay denied even if someone later adds a rule that allows it. Prove this: also create an `ALLOW` policy that explicitly allows the `/admin` paths, and leave it in place.

The result must be:

| From | Call | Expected |
| --- | --- | --- |
| `tester` | `POST /book` on `booking-service` | `200` |
| `tester` | `GET /book` on `booking-service` | `403` |
| `tester` | `POST /notify` on `notification-service` | `403` |
| `booking-service` | `POST /notify` on `notification-service` | `200` |
| `tester` | `GET /admin` on `notification-service` | `403` |
| `tester` | `GET /admin/users` on `notification-service` | `403` |

## Leave alone

* Do not delete the `ALLOW` policy for `/admin` to make the test pass.
* Do not change or remove the `PeerAuthentication`.

The grader checks that a `DENY` policy and a `principals` rule exist, that an `ALLOW` policy still names an `/admin` path, and then sends all six calls.
