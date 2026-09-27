# Exam Question: LAB015-010-03 — Migrate A Namespace To STRICT mTLS

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile) and two namespaces:

- **`migrate-demo`** — injected. `booking-service-v1`, `notification-service-v1`
  (container port `8084`) and a `tester` client pod. No `PeerAuthentication`, so
  it is implicitly `PERMISSIVE`.
- **`outside`** — not injected. One `outside-client` pod that calls
  `notification-service.migrate-demo` in plaintext.

## Task

Get `migrate-demo` to `STRICT` mutual TLS **without breaking `outside-client`**.

1. Establish, from the receiving proxy's telemetry, that plaintext is currently
   arriving. (Not graded directly — but do it before step 2, because it is the
   step that tells you the flip is unsafe.)
2. Bring `outside-client` into the mesh. It must end up running with an
   `istio-proxy` container.
3. Enforce `STRICT` for the `migrate-demo` namespace.
4. Confirm both `tester` and `outside-client` still reach
   `POST http://notification-service.migrate-demo/notify` afterwards.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not delete `outside-client`, and do not move it into `migrate-demo` — it
  must be migrated where it is.
- Do not solve step 3 with a workload-scoped policy: the whole namespace is in
  scope.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks that `outside-client` now carries a sidecar, that
`migrate-demo` has a namespace-wide `STRICT` policy, and that both callers still
get `200`.

When finished:

```sh
astrona destroy ats-015-lab-010-03
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
