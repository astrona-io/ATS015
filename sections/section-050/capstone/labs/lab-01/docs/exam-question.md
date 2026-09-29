# Exam Question: CAP015-050 — Edge Authorization Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, two parts)

---

## Context

A `kind` cluster with Istio 1.30.5 (`demo` profile). The ingress gateway runs in
`istio-system` with the label `istio: ingressgateway`, and the mesh is installed
with **`meshConfig.gatewayTopology.numTrustedProxies: 1`** — one trusted proxy
hop in front of the gateway.

Namespace `gwauthz-demo` is injected and running `booking-service-v1` (serving
`/book`, and **no `/admin` handler**) and `notification-service-v1`. A `Gateway`
and `VirtualService` for `booking.ica.local` on port 80 are already applied.

Because `booking-service` has no `/admin` handler, an `/admin` request that is
*not* blocked returns `404` — which is how you tell "refused at the edge" from
"reached the application".

No [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exists.

> **`kind` has no load balancer.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80`.

## Task

Two rules at the edge, layered:

1. **A global block-list.** Clients in `192.168.0.0/16` are denied everything on
   this gateway.
2. **An office-only admin path.** Requests for `/admin` *and anything beneath it*
   are denied **unless** the client is in `203.0.113.0/24`. Every other path
   stays open to everyone not caught by rule 1.

Both rules must match the **originating client** address, not the address of
whatever opened the TCP connection.

The observable result, calling with `Host: booking.ica.local`:

| `X-Forwarded-For` | Path | Expected |
| --- | --- | --- |
| `10.1.2.3` | `/book` | `200` |
| `192.168.5.5` | `/book` | `403` |
| `10.1.2.3` | `/admin` | `403` |
| `203.0.113.9` | `/admin` | not `403` |
| `192.168.5.5` | `/admin` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not change the `Gateway` or `VirtualService`, and do not reinstall Istio.
- Rule 2 must not close anything other than the `/admin` subtree.

## How you will be graded

```sh
astrona submit -c .
```

When finished:

```sh
astrona destroy ats-015-capstone-050
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
