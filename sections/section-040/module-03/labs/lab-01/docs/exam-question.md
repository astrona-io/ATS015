# Exam Question: LAB015-040-03 — Route An Encrypted Stream By SNI

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile) and its ingress gateway in
`istio-system`. Namespace `passthrough-demo` is injected and running:

- **`tls-backend`** — an nginx that **generates its own self-signed certificate
  at startup** (`CN=secure.ica.local`, `O=backend`) and serves HTTPS directly on
  container port `8443`, fronted by a Service on `8443`.

No `Gateway` and no `VirtualService` exist. There is no TLS secret anywhere, and
you will not need one.

> **`kind` has no load balancer.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Task

Expose `tls-backend` at the edge for the hostname `secure.ica.local` **without
the gateway decrypting anything**. The backend must remain the end that
terminates TLS.

1. Create a `Gateway` named **`passthrough-gateway`** in `passthrough-demo` with
   a port `443` listener for `secure.ica.local` that does not terminate TLS.
2. Create a `VirtualService` named **`passthrough`** in `passthrough-demo` that
   routes that traffic to `tls-backend` on port `8443`.

The observable result:

| Check | Expected |
| --- | --- |
| `https://secure.ica.local:8443/` via the gateway (`-k`) | `200` |
| the certificate the client is served | the backend's own (`O=backend`) |
| HTTP routes for `secure.ica.local` on the gateway | **none** — that is correct here |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not create a TLS credential for the gateway, and do not change `tls-backend`.
- The object names above are graded.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor calls the gateway with the right SNI, checks the certificate it is
served belongs to the backend, and confirms the gateway has no HTTP route for
that host.

When finished:

```sh
astrona destroy ats-015-lab-040-03
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [istioctl analyze](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-analyze) — the cross-object checks and their IST codes
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
