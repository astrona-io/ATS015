---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

Two services are moving behind the same ingress gateway, on the same port, and they need opposite things. The booking service is a normal public HTTPS service: you hold its certificate, and the gateway should decrypt each request so it can route by path. The other team refuses to hand over their key: nothing in the middle may decrypt their traffic. Both must work on port `443` at the same time.

A few words before you start:

* The **ingress gateway** is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. A **`Gateway`** object tells it which ports and hostnames to listen on.
* **TLS termination** (`tls.mode: SIMPLE`) means the gateway decrypts the connection and sends the request on inside. It needs its own certificate and key, kept in a Kubernetes Secret (the **gateway credential**, named in `credentialName`).
* **TLS passthrough** (`tls.mode: PASSTHROUGH`) means the gateway forwards the encrypted connection without decrypting it. Only the destination workload can decrypt it.
* **SNI** (Server Name Indication) is the hostname the client sends, unencrypted, at the start of the TLS handshake. The gateway reads it to pick a listener before anything is decrypted.
* A **`VirtualService`** holds routing rules: it says where a request goes once it has passed the gateway.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile, with its ingress gateway in `istio-system`. The namespace `tls-demo` has sidecar injection on and runs:

| Workload | Serves |
| --- | --- |
| `booking-service-v1` | plain HTTP `/book`, Service `booking-service` on port `80` |
| `notification-service-v1` | plain HTTP, Service `notification-service` on port `80` |
| `tls-backend` | **HTTPS on port `8443`**, with a certificate it makes itself (`CN=secure.ica.local`, `O=backend`) |

The setup left certificate material for the terminated hostname on your machine:

```text
/tmp/booking.crt    a self-signed certificate for CN=booking.ica.local
/tmp/booking.key    its private key, not encrypted
```

No `Gateway`, no `VirtualService` and no TLS secret exist yet.

`kind` has no load balancer. Reach the gateway with `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443` (and `8080:80` for the redirect).

## Your task

Build **one** `Gateway` named **`edge-gateway`** in `tls-demo` that serves two hostnames in two different modes, plus a redirect:

1. **`booking.ica.local`, terminated.** HTTPS on port `443`, using a credential named **`booking-credential`**. Route `/book` to `booking-service` on port `80`.
2. **`secure.ica.local`, passthrough.** Port `443`, not decrypted at the gateway, routed to `tls-backend` on port `8443`. `tls-backend` must stay the end that decrypts the traffic. Do not create a credential for this hostname.
3. **Port `80`** for `booking.ica.local` redirects to HTTPS instead of serving the page.

The result must be:

| Call | Expected |
| --- | --- |
| `https://booking.ica.local/book` | `200`, served with the `CN=booking.ica.local` certificate |
| `https://secure.ica.local/` | `200`, served with the **backend's** certificate (`O=backend`) |
| `http://.../book` with `Host: booking.ica.local` | `301` |

## Leave alone

* Use one `Gateway` object, named `edge-gateway`. Do not split it into two.
* Do not change `tls-backend`.

The grader checks the secret and the `Gateway`, calls both hostnames with the right SNI, checks which certificate each one is served, and checks the redirect.
