# Exam Question: LAB015-040-02 — Require Client Certificates At The Edge

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile) and its ingress gateway in
`istio-system`. Namespace `mtlsedge-demo` is injected and running
`booking-service-v1` (serving `/book`) and `notification-service-v1`.

The bootstrap has left a complete PKI for you:

```text
/tmp/ca.crt        the CA certificate  (public — clients are verified against this)
/tmp/ca.key        the CA private key
/tmp/booking.crt   a server certificate for CN=booking.ica.local, signed by that CA
/tmp/booking.key   its private key
/tmp/client.crt    a client certificate for CN=client.ica.local, signed by that CA
/tmp/client.key    its private key
```

No `Gateway`, no `VirtualService` and no secret exist.

> **`kind` has no load balancer.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Task

Expose `booking-service` at `booking.ica.local` over HTTPS, and require every
client to present a certificate signed by the supplied CA.

1. Create a secret named **`booking-credential-mtls`**, readable by the ingress
   gateway, containing the server certificate, its key, **and** the CA bundle.
2. Create a `Gateway` named **`booking-gateway`** in `mtlsedge-demo` whose port
   `443` listener for `booking.ica.local` uses `mode: MUTUAL` with that
   credential.
3. Create a `VirtualService` named **`booking`** routing `/book` on that host to
   `booking-service` on port 80.

The observable result:

| Call | Expected |
| --- | --- |
| HTTPS with `--cert /tmp/client.crt --key /tmp/client.key` | `200` |
| HTTPS with no client certificate | fails in the TLS handshake (`000`) |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- The object names above are graded.
- A request succeeding is **not** sufficient — grading also reads the gateway's
  own configuration to confirm client verification is actually enabled.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor checks the secret's key names, reads `requireClientCertificate` off
the gateway listener, then calls the gateway with and without a client
certificate.

When finished:

```sh
astrona destroy ats-015-lab-040-02
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
