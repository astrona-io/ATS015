# Exam Question: LAB015-060-01 — Enforce L4 And L7 Policy In Ambient Mode

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio installed using the **`ambient`** profile — istiod
plus the `ztunnel` DaemonSet, and **no sidecars anywhere**. The Gateway API CRDs
are installed.

Namespace `ambient-authz` is labelled `istio.io/dataplane-mode=ambient`, so its
pods are already enrolled, and runs:

| Workload | Service account | Notes |
| --- | --- | --- |
| `notification-service-v1` | `default` | container port `8084`, Service on port 80 |
| `tester` | **`tester-sa`** | a `curl` pod |
| `other-client` | **`other-sa`** | a `curl` pod |

No waypoint and no `AuthorizationPolicy` exist. Enrolment is a precondition; the
policies and the waypoint are the task.

## Task

In namespace `ambient-authz`, on `notification-service`:

1. Deploy a waypoint and enrol the namespace's traffic through it. Methods are
   an L7 concern, and ztunnel alone does not parse requests.
2. Allow **only** the `tester-sa` identity, and only the **`POST`** method.
   `other-sa` must be refused, and so must a `GET` from `tester-sa`.
3. Attach that policy with **`targetRefs`** naming the Service, not with a label
   `selector`.

Write it as **one** policy. A second, pod-selecting policy that names only
`tester-sa` will not do what it looks like it does: once the service has a
waypoint, every connection to the pod arrives from the **waypoint's** identity,
so such a rule refuses the waypoint and the service stops answering anyone.
Two ALLOW policies on the same target are also additive, so a policy without
`methods` would re-permit the `GET` the other one denies.

The observable result:

| From | Request | Expected |
| --- | --- | --- |
| `other-client` | `POST /notify` | refused by the waypoint (`403`) |
| `tester` | `POST /notify` | `200` |
| `tester` | `GET /notify` | `403` |

Note the two different failure shapes. They come from different components, and
getting `403` where `000` is expected (or the reverse) means the rules are at the
wrong layer.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not add sidecars or change the dataplane mode.
- Do not change any Deployment, Service or ServiceAccount.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks that a waypoint exists and is enrolled, that an L7 policy uses
`targetRefs`, and then sends the three calls above.

When finished:

```sh
astrona destroy ats-015-lab-060-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
