---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

A colleague set up the ingress gateway to pass the encrypted traffic of `tls-backend` through without decrypting it. `kubectl apply` accepted every object, but every client that asks for `tls-backend` through the gateway gets no response at all. Find out why, and fix it.

Istio 1.30.5 is installed with Helm. The ingress gateway, an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster, runs in the namespace `istio-ingress`: its Deployment and Service are both called `istio-ingress`, and its pods carry the label `istio: ingress`. The namespace `starfleet` has sidecar injection on and holds:

* `tls-backend`: an nginx server that makes **its own** self-signed certificate when it starts (`CN=vault.starfleet.example.com`, `O=vault`) and ends TLS itself on port `8443`, behind a Service `tls-backend` on port `8443`. It answers every path with `vault ended TLS itself`.
* The Starfleet (`bridge`, `cargo`, `scout` v1-v3, `navcom`) and the `shuttle` client. You do not need them for this task.

Two Istio objects already exist in `starfleet`:

* A `Gateway` named `vault-gateway`.
* A `VirtualService` named `tls-backend`.

`kind` has no load balancer, so reach the gateway's port `443` with a port forward:

```bash
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
```

Fix the setup so that:

1.  `vault-gateway` has a server on **port `443`** for the host **`vault.starfleet.example.com`** that **does not decrypt**: `protocol: TLS`, `mode: PASSTHROUGH`, and no `credentialName`.
2.  The `VirtualService` `tls-backend` stays bound to `vault-gateway` and routes the traffic by its **SNI name** `vault.starfleet.example.com` to `tls-backend` on port **`8443`**. It must have **no `http` block**.
3.  A request to `https://vault.starfleet.example.com/` through the gateway, sent with that SNI name, returns **`200`** and the reply `vault ended TLS itself`.
4.  The certificate the client gets through the gateway is the certificate that `tls-backend` made itself (`O=vault`).
5.  The gateway holds **no** HTTP route for `vault.starfleet.example.com`.
6.  Do not change `tls-backend` (its Deployment, ConfigMap or Service), and do not create a TLS secret.

The grader sends a real request through the gateway and reads the gateway's proxy configuration, so the fix has to work, not merely exist.
