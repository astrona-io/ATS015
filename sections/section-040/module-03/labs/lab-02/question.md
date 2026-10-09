---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, a fellow astronaut set up the arrival gate to pass the vault's sealed signals through unopened. `kubectl apply` accepted every object, but every visitor who asks for the vault through the gate gets no answer at all. Find out why, and fix it.

Istio 1.30.5 is installed with Helm. The ingress gateway (the arrival gate) runs on the planet `istio-ingress`: its Deployment and Service are both called `istio-ingress`, and its pods carry the label `istio: ingress`. The planet `starfleet` has sidecar injection on and holds:

* `tls-backend`, **the vault**: an nginx ship that makes **its own** self-signed certificate when it starts (`CN=vault.starfleet.example.com`, `O=vault`) and ends TLS itself on port `8443`, behind a Service `tls-backend` on port `8443`. It answers every path with `vault ended TLS itself`.
* The Starfleet (`bridge`, `cargo`, `scout` v1-v3, `navcom`) and the `shuttle` client. You do not need them for this task.

Two Istio objects already exist in `starfleet`:

* A `Gateway` named `vault-gateway`.
* A `VirtualService` named `tls-backend`.

`kind` has no load balancer, so reach the gate's port `443` with a port forward:

```bash
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
```

Fix the setup so that:

1.  `vault-gateway` has a server on **port `443`** for the host **`vault.starfleet.example.com`** that **does not decrypt**: `protocol: TLS`, `mode: PASSTHROUGH`, and no `credentialName`.
2.  The `VirtualService` `tls-backend` stays bound to `vault-gateway` and routes the traffic by its **SNI name** `vault.starfleet.example.com` to `tls-backend` on port **`8443`**. It must have **no `http` block**.
3.  A signal to `https://vault.starfleet.example.com/` through the gate, sent with that SNI name, returns **`200`** and the reply `vault ended TLS itself`.
4.  The certificate the visitor gets through the gate is the vault's own (`O=vault`).
5.  The gate holds **no** HTTP route for `vault.starfleet.example.com`.
6.  Do not change `tls-backend` (its Deployment, ConfigMap or Service), and do not create a TLS secret.

The grader sends a real signal through the gate and reads the gate's proxy, so the fix has to work, not merely exist.
