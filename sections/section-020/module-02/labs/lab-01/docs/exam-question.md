# Exam Question: LAB015-020-02 — Close A Path With DENY

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile). Namespace `deny-demo` is injected,
under **`STRICT`** mutual TLS, and running `booking-service-v1`,
`notification-service-v1` and a `tester` client pod.

`notification-service` serves `POST /notify`. It has **no `/admin` handler**, so
an `/admin` request that is *not* blocked returns `404` from the application —
which is how you tell "refused by the mesh" from "reached the app".

No [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exists.

## Task

On `notification-service`, in namespace `deny-demo`:

1. **Allow** `POST /notify` from any workload in the `deny-demo` namespace.
2. **Deny** every request whose path is `/admin` **or anything beneath it**.
3. Also create an `ALLOW` policy that explicitly permits `GET /admin` on the same
   workload — and leave it in place.

Requirement 3 is deliberate. The end state must be that `/admin` is still
refused even though a policy explicitly allows it. If your configuration lets
`/admin` through, you have the evaluation order wrong.

The observable result, all from `tester`:

| Call | Expected |
| --- | --- |
| `POST /notify` | `200` |
| `GET /admin` | `403` |
| `GET /admin/users` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not delete the `ALLOW` policy from requirement 3 to make the test pass.
- Do not solve requirement 2 by removing the `/notify` allowance.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks that a `DENY` policy exists, that an `ALLOW` naming `/admin`
also exists, and then sends the three calls above.

When finished:

```sh
astrona destroy ats-015-lab-020-02
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [Mutual TLS modes](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication) — what each mode accepts and rejects
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
