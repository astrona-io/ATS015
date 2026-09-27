# Terminate TLS At The Ingress Gateway

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-040/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-01/playground
> astrona destroy ats-015-playground-040-01
> ```

Everything so far has been traffic *inside* the mesh, where Istio issues the certificates and both ends are workloads it knows. The edge is different. A browser arrives from outside, expects HTTPS, and will check the certificate against a name it already trusts — so the certificate has to be one you supply, not one the mesh minted.

The configuration is short. What makes this task fail, reliably and for almost everyone the first time, is a namespace: the gateway reads its certificate from a secret **in its own namespace**, not in the namespace where the `Gateway` object lives.

## How this module is organised

1. **[Part 1 — How a gateway gets its certificate](./course-01-how-a-gateway-gets-its-certificate.md)** — the SDS delivery path, why `credentialName` resolves in the gateway pod's namespace, and building the secret.
2. **[Part 2 — The TLS listener](./course-02-the-tls-listener.md)** — the `Gateway` server block field by field, how the port name shapes protocol handling, and how SNI selects between listeners.
3. **[Part 3 — Verifying, redirecting and rotating](./course-03-verifying-redirecting-and-rotating.md)** — proving which certificate was served, the HTTP-to-HTTPS redirect, restart-free rotation, and the pitfalls.

## Learning objectives

After this module you can:

- Describe how a credential reaches the gateway proxy, and explain why the secret must live in the gateway pod's namespace.
- Create a Kubernetes TLS secret with the key names Istio expects, and say why `kubectl create secret tls` is the right tool for `SIMPLE`.
- Write a `Gateway` with a `SIMPLE` TLS listener, naming the credential with `credentialName`.
- Say which two properties of the port block a TLS listener depends on, and what a wrong port name changes.
- Explain how SNI selects a listener and why a test without it fails in a way that looks like a certificate problem.
- Prove from the handshake, and from the proxy's own configuration, which certificate a gateway is serving.
- Add an HTTP-to-HTTPS redirect with `tls.httpsRedirect`, and rotate a certificate without restarting the gateway.

## Before you start

You should know what a `Gateway` and a `VirtualService` do — a `Gateway` configures a listener on an edge proxy, a `VirtualService` says where matching requests go. You do not need to have written either before; the shapes are shown in full.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile), which includes the `istio-ingressgateway` Deployment in `istio-system`, plus `istioctl` and `openssl` on your PATH:

- **`tls-demo`** — injected. `booking-service-v1` (serving `/book`) and `notification-service-v1`, both fronted by Services on port 80.

No `Gateway`, no `VirtualService` and no TLS secret exist yet.

**`kind` has no load balancer.** The `istio-ingressgateway` Service will sit at `EXTERNAL-IP: <pending>` forever, and that is expected rather than broken. Every test in this module reaches the gateway through `kubectl port-forward`.

## Where this fits

Mesh mTLS and edge TLS solve different problems and are easy to conflate because both end in "TLS". Inside the mesh, both parties are workloads, the mesh CA issues both certificates, and the point is mutual proof of identity. At the edge, the client is a browser or an external system, the certificate must be one that client already trusts, and the point is server authentication plus encryption. The gateway is where the two meet: it terminates the external connection and re-originates mesh traffic on the inside.
