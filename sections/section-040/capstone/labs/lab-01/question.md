---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

Astronaut, two services are moving behind the same spaceport arrival gate, on the same port, and they want opposite things. The booking service is a normal public HTTPS service: you hold its certificate, and the gate should open each signal so it can route by path. The other team refuses to hand over their key: nothing in the middle may open their signals. Both must work on port `443` at the same time.

A few words before you start:

* The **ingress gateway** is the spaceport arrival gate: the one door signals from outside the solar system come through. A **`Gateway`** object tells it which ports and hostnames to open.
* **TLS termination** (`tls.mode: SIMPLE`) means the gate opens the sealed signal, checks it, and sends it on inside. It needs its own badge and key, kept in a Kubernetes Secret (the **gateway credential**, named in `credentialName`).
* **TLS passthrough** (`tls.mode: PASSTHROUGH`) means the gate forwards the sealed signal unopened. Only the destination ship can open it.
* **SNI** (Server Name Indication) is the address written on the outside of the sealed envelope. The gate reads it to pick a listener before anything is opened.
* A **`VirtualService`** is the flight plan: it says where a signal goes once it is through the gate.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile, with its ingress gateway in `istio-system`. The planet `tls-demo` has sidecar injection on and runs:

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
2. **`secure.ica.local`, passthrough.** Port `443`, not opened at the gate, routed to `tls-backend` on port `8443`. `tls-backend` must stay the end that opens the signal. Do not create a credential for this hostname.
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
