---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, a fellow astronaut set up HTTPS for the bridge, and it does not work. Every HTTPS signal to `https://starfleet.example.com/productpage` fails in the handshake, with no HTTP status at all. Kubernetes accepted every object, and nobody saw an error.

The cluster has Istio 1.30.5, installed with Helm. The ingress gateway runs in the namespace `istio-ingress`: its Deployment and its Service are both called `istio-ingress`, and its pods carry the label `istio: ingress`. The planet `starfleet` runs the Starfleet (`bridge` on port `9080`, `cargo`, `navcom`, `scout` v1-v3) and the `shuttle` client.

These objects already exist in `starfleet`:

* A TLS Secret named `starfleet-credential`. Its certificate and key are correct: a server certificate for `starfleet.example.com`, signed by a test CA.
* A ConfigMap named `starfleet-ca`. Its key `ca.crt` is the test CA's certificate, the one clients must trust.
* A `Gateway` named `starfleet-gateway`, with one `SIMPLE` TLS server on port `443`.
* A `VirtualService` named `bridge` that routes `/productpage` on `starfleet.example.com`, through `starfleet-gateway`, to the bridge. **This flight plan is correct.**

`astrona run` keeps a port forward from `127.0.0.1:8443` to the gateway's port `443`. Get the CA onto your machine and test with it:

```sh
kubectl get configmap starfleet-ca -n starfleet -o jsonpath='{.data.ca\.crt}' > starfleet-ca.crt
curl -s -o /dev/null -w "%{http_code} " --cacert starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 https://starfleet.example.com:8443/productpage; echo "exit=$?"
```

Fix the problem so that:

1.  A TLS Secret named **`starfleet-credential`** exists in the namespace where the ingress gateway reads it, with the keys `tls.crt` and `tls.key`, holding the same certificate and key the lab created (signed by the CA in `starfleet-ca`).
2.  The `Gateway` named **`starfleet-gateway`** in `starfleet` has a server on port `443` with protocol `HTTPS` for the host **`starfleet.example.com`**, `tls.mode: SIMPLE` and `credentialName: starfleet-credential`.
3.  The gateway proxy holds `starfleet-credential` as `ACTIVE`, and `istioctl analyze -n starfleet` reports no `IST0101` for the `Gateway`.
4.  HTTPS signals to `https://starfleet.example.com/productpage` that trust only the CA in `starfleet-ca` (no `-k`) get `200`, with curl exit code `0`.
5.  The `VirtualService` named `bridge` stays linked to `starfleet-gateway` for `starfleet.example.com`. Leave the ConfigMap `starfleet-ca`, the Deployments and the Services unchanged.

The grader reads the Secret, the `Gateway` and the gateway proxy, and then sends live HTTPS signals through its own port forward, so the fix has to work, not merely exist.
