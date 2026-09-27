# Exam Question: LAB015-010-01 — Prove A Workload Identity And Authorize On It

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A single-node `kind` cluster with Istio installed (`demo` profile). Namespace
`identity-demo` is injected and already running:

| Workload | Service account | Serves |
| --- | --- | --- |
| `booking-service-v1` | `booking-sa` | `POST /book` on port 8084 |
| `notification-service-v1` | `default` | `POST /notify` on port 8084 |
| `tester` | `default` | a `curl` pod, no server |

No `PeerAuthentication` and no `AuthorizationPolicy` exist. Every workload can
currently call every other one.

## Task

In namespace `identity-demo`:

1. Enforce **`STRICT`** mutual TLS for the whole namespace, so that workload
   identities are verifiable.
2. Restrict `notification-service` so that **only `booking-service`** may reach
   it. Match on the caller's **mesh identity**, not its namespace, labels or
   address.
3. Derive the identity from the certificate the workload is actually presenting —
   do not guess it. `istioctl proxy-config secret` and `openssl x509` will show
   you the SAN.

The end state must be that `booking-service` can call
`POST http://notification-service/notify` and `tester` cannot.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not change any Deployment, Service or ServiceAccount — solve this with Istio
  objects only.
- Object names are yours to choose; the identity string is not.

## How you will be graded

From this lab directory:

```sh
astrona submit -c .
```

The Proctor checks that the objects exist, then sends real traffic: the call from
`booking-service` must succeed and the call from `tester` must be refused with
`403`. A `PROCTOR: PASS` verdict and exit code `0` mean you are done.

When finished:

```sh
astrona destroy ats-015-lab-010-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
