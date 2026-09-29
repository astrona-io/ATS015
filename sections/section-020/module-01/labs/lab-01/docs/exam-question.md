# Exam Question: LAB015-020-01 — Lock A Namespace Down With ALLOW Policies

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile). Namespace `authz-demo` is injected,
already under **`STRICT`** mutual TLS, and running:

| Workload | Service account | Serves |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | `POST /book` on port 8084 |
| `notification-service-v1` | `default` | `POST /notify` on port 8084 |
| `tester` | `default` | a `curl` pod |

No [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exists, so every call currently succeeds.

## Task

Using `AuthorizationPolicy` objects only, produce this end state in `authz-demo`:

1. The namespace is **deny-by-default**: any workload for which nothing else is
   written is unreachable.
2. `booking-service` accepts **`POST /book`** from any workload in the
   `authz-demo` namespace, and nothing else.
3. `notification-service` accepts **`POST /notify`** from the
   **`booking-sa` identity only**, and nothing else.

The observable result:

| From | Call | Expected |
| --- | --- | --- |
| `tester` | `POST /book` on `booking-service` | `200` |
| `tester` | `GET /book` on `booking-service` | `403` |
| `tester` | `POST /notify` on `notification-service` | `403` |
| `booking-service` | `POST /notify` on `notification-service` | `200` |
| `booking-service` | `GET /notify` on `notification-service` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not change or remove the [`PeerAuthentication`](https://istio.io/latest/docs/reference/config/security/peer_authentication/) — identity-based rules depend
  on it.
- Rule 3 must match on the caller's identity, not on its namespace.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor sends all five calls above and asserts each result.

When finished:

```sh
astrona destroy ats-015-lab-020-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [PeerAuthentication API](https://istio.io/latest/docs/reference/config/security/peer_authentication/) — `mtls.mode` and the scoping rules
- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [Mutual TLS modes](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication) — what each mode accepts and rejects
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/) — the SPIFFE identity format and where it comes from
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
