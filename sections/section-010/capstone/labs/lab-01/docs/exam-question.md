# Exam Question: CAP015-010 — Workload Identity And Mutual TLS Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, three parts)

---

## Context

A `kind` cluster with Istio (`demo` profile) and two namespaces:

- **`identity-demo`** — injected. `booking-service-v1` (service account
  **`booking-sa`**), `notification-service-v1` (`default`) and a `tester` pod
  (`default`).
- **`outside`** — **not** injected. One `outside-client` pod calling
  `booking-service.identity-demo` in plaintext.

No [`PeerAuthentication`](https://istio.io/latest/docs/reference/config/security/peer_authentication/) and no [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exist.

## Task

This capstone combines all three modules of the section. Produce this end state:

1. **Mesh-wide mutual TLS.** `STRICT` is the default for the whole mesh, declared
   in the right place for that scope.
2. **No caller left behind.** `outside-client` must end up inside the mesh and
   still able to reach `booking-service`. Do this *before* step 1 takes effect
   for it, or you will break it.
3. **Authorize on identity.** `notification-service` accepts traffic only from
   the **`booking-sa`** identity. Read that identity off the certificate the
   workload is actually presenting rather than assembling it from memory.

The observable result:

| From | To | Expected |
| --- | --- | --- |
| `booking-service` | `POST /notify` | `200` |
| `tester` | `POST /notify` | `403` |
| `outside-client` | `POST /book` on `booking-service` | `200` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not delete `outside-client` or move it to another namespace.
- Rule 3 must match on identity, not on namespace, labels or address.
- Rule 1 must be mesh-scoped — a namespace policy is not sufficient.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks the mesh-scoped policy, that `outside-client` carries a
sidecar, and then sends all three calls.

When finished:

```sh
astrona destroy ats-015-capstone-010
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
- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
