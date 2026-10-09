---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

A partner reports trouble. The ingress gateway in front of the `starfleet` namespace asks every client for a client certificate, as it should. But the trusted partner, whose certificate was signed by your certificate authority (CA), is refused during the TLS handshake. And an unknown client (the "stranger"), with a certificate from another CA, gets straight through to the `bridge`.

The namespace `starfleet` runs the Starfleet sample app:

* `bridge`: the web frontend, a Service on port `9080`. It answers on `/productpage`.
* `cargo`, `navcom` and `scout` v1, v2 and v3: the backends.
* `shuttle`: a client pod with `curl`.

Istio 1.30.5 is installed with Helm. The ingress gateway runs in the namespace `istio-ingress`: its Deployment and its Service are both called `istio-ingress`, and its pods carry the label `istio: ingress`.

The bootstrap made these files on your machine, in `/tmp/ats-015-lab-040-02-02/`:

| File | What it is |
| --- | --- |
| `example.com.crt` | your CA, the one the gateway must trust |
| `starfleet.example.com.crt`, `starfleet.example.com.key` | the gateway's server certificate and key, signed by `example.com` |
| `partner.crt`, `partner.key` | the partner's client certificate and key, signed by `example.com` |
| `other-ca.crt` | the other CA, which signed the stranger's certificate |
| `stranger.crt`, `stranger.key` | the stranger's client certificate and key, signed by `other-ca` |

Three objects already exist:

* A `Gateway` named `starfleet-gateway` in `starfleet`, with one server on port `443` for `starfleet.example.com`, `mode: MUTUAL` and `credentialName: starfleet-credential-mutual`. **This `Gateway` is correct.**
* A `VirtualService` named `bridge` in `starfleet`, linked to `starfleet-gateway`, that sends `/productpage` to `bridge` on port `9080`. **This `VirtualService` is correct.**
* A secret named `starfleet-credential-mutual` in `istio-ingress`. Something in it is wrong.

`kind` has no load balancer, so reach the gateway with a port forward, and send the real host name with `--resolve`:

```bash
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
cd /tmp/ats-015-lab-040-02-02
curl -s -o /dev/null -w "%{http_code}\n" --cacert example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 \
  --cert partner.crt --key partner.key https://starfleet.example.com:8443/productpage
```

A refused handshake can end the port forward. If curl cannot connect at all, start the port forward again.

Fix the problem so that:

1.  The secret `starfleet-credential-mutual` in `istio-ingress` still holds the gateway's server certificate and key as `tls.crt` and `tls.key`.
2.  Its `ca.crt` holds your CA, `example.com.crt`, and **not** the other CA.
3.  The gateway's proxy holds the CA as `kubernetes://starfleet-credential-mutual-cacert` with status `ACTIVE`, and its listener has `requireClientCertificate: true`.
4.  A request to `/productpage` with the partner's certificate gets `200` through the gateway.
5.  A request with no client certificate, and a request with the stranger's certificate, are both refused during the TLS handshake (curl prints `000`).
6.  The `Gateway` named `starfleet-gateway` and the `VirtualService` named `bridge` are **left unchanged**.
7.  Leave the files in `/tmp/ats-015-lab-040-02-02/`, the gateway Deployment and the Starfleet unchanged.

The grader reads the secret and the gateway's proxy, and then sends real requests through the gateway with each certificate, so the fix has to work, not merely exist.
