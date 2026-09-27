# Exam Question: CAP015-020 — Authorization Policy Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, three parts)

---

## Context

A `kind` cluster with Istio 1.30.5 (`demo` profile). Namespace `authz-demo` is
injected, already under **`STRICT`** mutual TLS, and running:

| Workload | Service account | Serves |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | `POST /book` |
| `notification-service-v1` | `default` | `POST /notify`, and **no `/admin` handler** |
| `tester` | `default` | a `curl` pod |

No `AuthorizationPolicy` exists. Because `notification-service` has no `/admin`
handler, an `/admin` request that is *not* blocked returns `404` — which is how
you tell "the mesh refused it" from "it reached the application".

## Task

This capstone combines both modules of the section. In `authz-demo`:

1. **Deny by default.** A workload nobody has written a rule for is unreachable.
2. **Reopen exactly two calls.** `POST /book` on `booking-service` from anything
   in the namespace; `POST /notify` on `notification-service` from the
   **`booking-sa` identity only**.
3. **Add a backstop.** Any request whose path is `/admin` *or anything beneath
   it* is denied on `notification-service` — and it must stay denied even if
   someone later adds a permissive rule for that path. Demonstrate that by
   also creating an `ALLOW` policy that explicitly permits `GET /admin`, and
   leaving it in place.

The observable result:

| From | Call | Expected |
| --- | --- | --- |
| `tester` | `POST /book` | `200` |
| `tester` | `GET /book` | `403` |
| `tester` | `POST /notify` | `403` |
| `booking-service` | `POST /notify` | `200` |
| `tester` | `GET /admin` on `notification-service` | `403` |
| `tester` | `GET /admin/users` on `notification-service` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not delete the permissive `/admin` policy to make the test pass.
- Do not change or remove the `PeerAuthentication`.

## How you will be graded

```sh
astrona submit -c .
```

When finished:

```sh
astrona destroy ats-015-capstone-020
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
