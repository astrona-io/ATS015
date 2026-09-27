# Exam Question: CAP015-060 — Ambient Authorization Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, three parts)

---

## Context

A `kind` cluster with Istio 1.30.5 installed using the **`ambient`** profile —
istiod plus the `ztunnel` DaemonSet, **no sidecars anywhere** — and the Gateway
API CRDs installed.

Namespace `ambient-authz` is labelled `istio.io/dataplane-mode=ambient`, so its
pods are enrolled, and runs:

| Workload | Service account | Notes |
| --- | --- | --- |
| `notification-service-v1` | `default` | container port `8084`, Service on port 80, serves `/notify` and has no `/admin` handler |
| `tester` | **`tester-sa`** | a `curl` pod |
| `other-client` | **`other-sa`** | a `curl` pod |

No waypoint and no `AuthorizationPolicy` exist.

## Task

Split one access requirement across the two ambient enforcement points:

1. **Connection level (ztunnel).** Only the `tester-sa` identity may connect to
   `notification-service`. This must be enforced with **no waypoint involved**,
   and attached with a label `selector`.
2. **Request level (waypoint).** The allowed identity may only send
   **`POST /notify`** — any other method, and any other path, is refused.
3. **Make part 2 real.** Deploy a waypoint and enrol traffic through it, and
   attach the request-level policy with **`targetRefs`**.

The observable result:

| From | Request | Expected |
| --- | --- | --- |
| `other-client` | `POST /notify` | refused at the connection (`000`) |
| `tester` | `POST /notify` | `200` |
| `tester` | `GET /notify` | `403` |
| `tester` | `POST /admin` | `403` |

The two failure shapes are graded. A `403` where `000` is expected means the rule
is at the wrong layer.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not add sidecars or change the dataplane mode.
- Do not change any Deployment, Service or ServiceAccount.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks that a waypoint exists and is enrolled, that ztunnel holds a
workload-scoped policy, that an L7 policy uses `targetRefs`, and then sends the
four calls.

When finished:

```sh
astrona destroy ats-015-capstone-060
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
