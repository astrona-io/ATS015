# Exam Question: LAB015-050-01 — Block A Client Range At The Gateway

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile). The ingress gateway runs in
`istio-system` with the label `istio: ingressgateway`.

Namespace `gwauthz-demo` is injected and running `booking-service-v1` (serving
`/book`) and `notification-service-v1`. A **`Gateway` and `VirtualService` for
`booking.ica.local` on port 80 are already applied** — they are the target of
your policy, not part of the task.

The mesh is already installed with
**`meshConfig.gatewayTopology.numTrustedProxies: 1`**, so exactly one trusted
proxy hop is assumed in front of the gateway. That is a precondition: you write
policy, not an install.

No [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exists.

> **`kind` has no load balancer.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80`.
> Remember that a port-forward makes the connection appear to come from inside
> the cluster — which is exactly why the field you need is not the obvious one.

## Task

Deny requests arriving at the ingress gateway from the client range
**`192.168.0.0/16`**, while leaving every other client able to reach
`booking.ica.local`.

1. Create an `AuthorizationPolicy` in the **gateway's** namespace that selects
   the ingress gateway pod.
2. Use the source field that matches the **originating client** — the address a
   trusted proxy forwarded — not the address of whatever opened the TCP
   connection.
3. Deny `192.168.0.0/16`; do not close anything else.

The observable result, calling `http://…/book` with `Host: booking.ica.local`:

| Request | Expected |
| --- | --- |
| `X-Forwarded-For: 10.1.2.3` | `200` |
| `X-Forwarded-For: 192.168.5.5` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not change the `Gateway` or `VirtualService`.
- Do not reinstall Istio or change `meshConfig`.
- An `ALLOW` policy that closes the whole gateway is not an acceptable solution —
  callers outside the denied range must still get through.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks the policy's namespace, selector and source field, then sends
both requests.

When finished:

```sh
astrona destroy ats-015-lab-050-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
