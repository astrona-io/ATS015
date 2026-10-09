---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The booking service is going public. You have been given a certificate and a private key for `booking.ica.local`. Put the service behind HTTPS at the ingress gateway, with plain HTTP requests redirected rather than served.

This lab runs a small app of its own, not the Starfleet. The cluster has Istio 1.30.5 with the `demo` profile, which includes the ingress gateway Deployment `istio-ingressgateway` in the namespace `istio-system`. Its pods carry the label `istio: ingressgateway`. The namespace `tls-demo` has sidecar injection on and runs:

* `booking-service-v1`: serves `/book`, behind the Service `booking-service` on port `80`.
* `notification-service-v1`: behind the Service `notification-service` on port `80`.
* `tester`: a client pod with `curl`.

The bootstrap left certificate material on your machine:

```text
/tmp/booking.crt    a self-signed certificate for CN=booking.ica.local
/tmp/booking.key    its unencrypted private key
```

No TLS Secret, no `Gateway` and no `VirtualService` exist.

Expose `booking-service` at the edge over HTTPS for the host name `booking.ica.local`:

1.  Store the certificate material as a Kubernetes TLS Secret named **`booking-credential`**, in the namespace where the ingress gateway can actually read it.
2.  Create a `Gateway` named **`booking-gateway`** in `tls-demo` with a `SIMPLE` TLS server on port `443` for `booking.ica.local` that uses that Secret.
3.  Create a `VirtualService` named **`booking`** in `tls-demo` that routes `/book` on that host, arriving through that `Gateway`, to `booking-service` on port `80`.
4.  Add a server on port `80` for the same host that **redirects** to HTTPS instead of serving anything.
5.  Keep the object names exactly as given, and leave the workloads and Services unchanged.

`kind` has no load balancer, so the gateway Service never gets an external address. Reach it with a port forward, for example:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 8080:80
```

When you are done, this is what you should see:

| Request | Expected |
| --- | --- |
| `https://booking.ica.local:8443/book` (through the port forward, with `--resolve` and `-k`) | `200`, with the `CN=booking.ica.local` certificate |
| `http://127.0.0.1:8080/book` with the header `Host: booking.ica.local` | `301` |

The grader opens its own port forward to the gateway, checks that the gateway proxy holds `booking-credential`, calls it over HTTPS with the right SNI, reads the certificate it is shown, and checks that port `80` answers with a redirect.
