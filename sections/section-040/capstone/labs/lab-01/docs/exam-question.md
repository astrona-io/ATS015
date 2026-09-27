# Exam Question: CAP015-040 — Edge TLS Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, three parts)

---

## Context

A `kind` cluster with Istio 1.30.5 (`demo` profile) and its ingress gateway in
`istio-system`. Namespace `tls-demo` is injected and running:

| Workload | Serves |
| --- | --- |
| `booking-service-v1` | plain HTTP `/book`, Service on port 80 |
| `notification-service-v1` | plain HTTP, Service on port 80 |
| `tls-backend` | **HTTPS on port 8443**, with a certificate it generates itself (`CN=secure.ica.local`, `O=backend`) |

The bootstrap has left certificate material for the *terminated* hostname:

```text
/tmp/booking.crt    a self-signed certificate for CN=booking.ica.local
/tmp/booking.key    its unencrypted private key
```

No `Gateway`, no `VirtualService` and no TLS secret exist.

> **`kind` has no load balancer.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`
> (and `8080:80` for the redirect).

## Task

Build **one** `Gateway` named **`edge-gateway`** in `tls-demo` that serves two
hostnames in two different modes, plus a redirect:

1. **`booking.ica.local` — terminated.** HTTPS on port 443 using a credential
   named **`booking-credential`**, routing `/book` to `booking-service` on port
   80.
2. **`secure.ica.local` — passthrough.** Port 443, not decrypted, routed to
   `tls-backend` on port 8443. The backend must remain the end that terminates
   TLS, and you must not create a credential for it.
3. **Port 80** for `booking.ica.local` redirects to HTTPS rather than serving.

The observable result:

| Call | Expected |
| --- | --- |
| `https://booking.ica.local/book` | `200`, served with the `CN=booking.ica.local` certificate |
| `https://secure.ica.local/` | `200`, served with the **backend's** certificate (`O=backend`) |
| `http://…/book` with `Host: booking.ica.local` | `301` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- One `Gateway` object, named `edge-gateway`. Do not split it into two.
- Do not change `tls-backend`.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor calls both hostnames with the correct SNI, checks which certificate
each one is served, and checks the redirect.

When finished:

```sh
astrona destroy ats-015-capstone-040
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
