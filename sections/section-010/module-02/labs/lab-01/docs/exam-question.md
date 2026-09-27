# Exam Question: LAB015-010-02 — Enforce mTLS At Three Scopes

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile) and two namespaces:

- **`mtls-demo`** — injected. `booking-service-v1`, `notification-service-v1`
  (both serving port 8084) and a `tester` client pod.
- **`outside`** — **not** injected. One `outside-client` pod with `curl` and no
  sidecar, so everything it sends is plaintext.

No `PeerAuthentication` exists anywhere, so the mesh default (`PERMISSIVE`)
applies and both callers currently succeed.

## Task

Produce this exact end state, using `PeerAuthentication` only:

1. **Mesh-wide:** `STRICT` is the default for the whole mesh.
2. **Namespace exception:** `mtls-demo` overrides that back to `PERMISSIVE`.
3. **Workload override:** within `mtls-demo`, `notification-service` is `STRICT`
   again — and `booking-service` is not.

The observable result, all from `outside-client`:

| Call | Expected |
| --- | --- |
| `POST http://notification-service.mtls-demo/notify` | refused at the transport |
| `POST http://booking-service.mtls-demo/book` | `200` |

and from `tester` inside the mesh, `POST http://notification-service/notify`
must still return `200`.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not add a sidecar to `outside-client`, and do not delete it — it is the only
  plaintext caller and grading needs it.
- Use `PeerAuthentication` only. No `AuthorizationPolicy`, no `DestinationRule`.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks the objects exist at the right scopes, then sends traffic from
both the unmeshed and the meshed caller and asserts each outcome.

When finished:

```sh
astrona destroy ats-015-lab-010-02
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
