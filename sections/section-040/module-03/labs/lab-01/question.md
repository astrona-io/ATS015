---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

A backend team runs a service that keeps its own certificate and private key. It shows its own certificate to every client, and nothing in the middle may decrypt its traffic. You still have to put it behind the shared ingress gateway, the Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster, next to everything else.

This lab uses its own small app, not the Starfleet. Istio 1.30.5 is installed with the `demo` profile, so the gateway `istio-ingressgateway` runs in `istio-system`, and its pods carry the label `istio: ingressgateway`. Namespace `passthrough-demo` has sidecar injection on and holds:

* `tls-backend`: an nginx that **makes its own self-signed certificate when it starts** (`CN=secure.ica.local`, `O=backend`) and serves HTTPS itself on container port `8443`, behind a Service on port `8443`.

No `Gateway` and no `VirtualService` exist. There is no TLS secret anywhere, and you do not need one.

`kind` has no load balancer, so reach the gateway's port `443` with a port forward:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
```

Expose `tls-backend` at the gateway for the host `secure.ica.local`, **without the gateway decrypting anything**. The backend must stay the end that finishes TLS.

1.  Create a `Gateway` named **`passthrough-gateway`** in namespace **`passthrough-demo`**, selecting the gateway pods with `istio: ingressgateway`.
2.  It must open a server on **port `443`** for the host `secure.ica.local` that **does not end TLS** and names **no** credential.
3.  Create a `VirtualService` named **`passthrough`** in `passthrough-demo`, bound to `passthrough-gateway`, that routes this traffic by its **SNI name** to `tls-backend` on port **`8443`**.
4.  Do not create a TLS secret for the gateway, and do not change `tls-backend`.

**What the grader checks**

5.  The `Gateway` server uses `protocol: TLS` and `mode: PASSTHROUGH`, with no `credentialName`.
6.  The `VirtualService` routes with a `tls` rule that matches on `sniHosts`.
7.  `https://secure.ica.local/` through the gateway, sent with the SNI name `secure.ica.local`, returns **`200`**.
8.  The certificate the client gets through the gateway is the backend's own (`O=backend`).
9.  The gateway has **no** HTTP route for `secure.ica.local`. That is correct for this mode.

The object names above are graded.
