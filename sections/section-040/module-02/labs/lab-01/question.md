---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The booking API is being opened to three partner systems, and to nobody else. Your organisation runs a certificate authority (CA) and has given each partner a client certificate. Make the ingress gateway refuse any client that cannot present one.

The cluster runs Istio 1.30.5, installed with the `demo` profile. The ingress gateway is the Deployment and Service `istio-ingressgateway` in `istio-system`, and its pods carry the label `istio: ingressgateway`. The namespace `mtlsedge-demo` has sidecar injection on and runs:

* `booking-service-v1`: a Service `booking-service` on port `80`. It answers on `/book`.
* `notification-service-v1` and a `tester` pod: the rest of the app.

The bootstrap has left the certificates on your machine:

```text
/tmp/ca.crt        the CA certificate (public: clients are checked against it)
/tmp/ca.key        the CA private key
/tmp/booking.crt   a server certificate for CN=booking.ica.local, signed by that CA
/tmp/booking.key   its private key
/tmp/client.crt    a client certificate for CN=client.ica.local, signed by that CA
/tmp/client.key    its private key
```

No `Gateway`, no `VirtualService` and no secret exist yet.

`kind` has no load balancer, so reach the gateway with a port forward, and send the right host name with `--resolve`:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
curl -sk --resolve booking.ica.local:8443:127.0.0.1 https://booking.ica.local:8443/book
```

Expose `booking-service` at `booking.ica.local` over HTTPS, and require every client to show a certificate signed by the supplied CA:

1.  Create a secret named **`booking-credential-mtls`** that the ingress gateway can read. It must hold the server certificate, its key **and** the CA certificate, under the keys `tls.crt`, `tls.key` and `ca.crt`.
2.  Create a `Gateway` named **`booking-gateway`** in `mtlsedge-demo` with a server on port `443` for `booking.ica.local` that uses `mode: MUTUAL` with that secret.
3.  Create a `VirtualService` named **`booking`** in `mtlsedge-demo` that sends `/book` on that host to `booking-service` on port `80`.

The result must be:

| Call | Expected |
| --- | --- |
| HTTPS with `--cert /tmp/client.crt --key /tmp/client.key` | `200` |
| HTTPS with no client certificate | refused during the TLS handshake (curl prints `000`) |

Leave the Deployments and Services in `mtlsedge-demo` unchanged. The object names above are graded.

The grader checks the secret's key names, reads `requireClientCertificate` from the gateway's own listener, and then calls the gateway with and without the client certificate. A request that succeeds is not enough on its own.
