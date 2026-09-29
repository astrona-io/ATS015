# Exam Question: LAB015-040-01 — Serve HTTPS At The Ingress Gateway

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile), which includes the
`istio-ingressgateway` Deployment in `istio-system`. Namespace `tls-demo` is
injected and running `booking-service-v1` (serving `/book`) and
`notification-service-v1`, both fronted by Services on port 80.

The bootstrap has left certificate material for you:

```text
/tmp/booking.crt    a self-signed certificate for CN=booking.ica.local
/tmp/booking.key    its unencrypted private key
```

No `Gateway`, no `VirtualService` and no TLS secret exist.

> **`kind` has no load balancer.** The gateway Service stays at
> `EXTERNAL-IP: <pending>`; that is expected. Reach it with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Task

Expose `booking-service` at the mesh edge over HTTPS for the hostname
`booking.ica.local`:

1. Store the certificate material as a Kubernetes TLS secret named
   **`booking-credential`**, where the ingress gateway can actually read it.
2. Create a `Gateway` named **`booking-gateway`** in `tls-demo` with a `SIMPLE`
   TLS listener on port `443` for `booking.ica.local`, using that credential.
3. Create a `VirtualService` named **`booking`** in `tls-demo` that routes
   `/book` on that host to `booking-service` on port 80.
4. Add a listener on port `80` for the same host that **redirects** to HTTPS
   rather than serving anything.

The observable result:

| Call | Expected |
| --- | --- |
| `https://booking.ica.local:8443/book` (via port-forward, `-k`) | `200`, served with the `CN=booking.ica.local` certificate |
| `http://…:8080/book` with `Host: booking.ica.local` | `301` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- The object names above are graded: `booking-credential`, `booking-gateway`, `booking`.
- Do not expose the service over plain HTTP as well — port 80 must only redirect.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor port-forwards the gateway, calls it over HTTPS with the right SNI,
checks the certificate it is served, and checks that port 80 answers `301`.

When finished:

```sh
astrona destroy ats-015-lab-040-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
