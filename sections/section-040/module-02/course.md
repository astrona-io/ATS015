# Require Client Certificates At The Edge

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-040/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-02/playground
> astrona destroy ats-015-playground-040-02
> ```

`SIMPLE` TLS proves the *server* is who it says it is. Anyone may connect. That is right for a public website and wrong for a partner API, a machine-to-machine integration, or anything where the list of legitimate callers is short and known in advance.

`MUTUAL` mode turns the check around as well: the gateway demands a certificate from the client and verifies it against a CA you nominate. The configuration difference from [Module 1](../module-01/course.md) is one word in the `Gateway` and one extra key in the secret — and the failure it produces looks nothing like an HTTP error.

## How this module is organised

1. **[Part 1 — Building the PKI](./course-01-building-the-pki.md)** — what a CA actually does, issuing a server and a client certificate, and the chain a verifier walks.
2. **[Part 2 — The credential secret and the validation context](./course-02-secret-and-validation-context.md)** — the third key, why `create secret tls` cannot build it, and turning the mode on.
3. **[Part 3 — Handshake failures, and what a certificate proves](./course-03-handshake-failures-and-identity.md)** — the client's view of a rejection, confirming enforcement is really on, and the gap between authentication and authorization.

## Learning objectives

After this module you can:

- Explain what a CA is in this context and what signing a certificate asserts.
- Build a small CA and issue a server and a client certificate from it with `openssl`.
- Create a credential secret carrying `tls.crt`, `tls.key` and `ca.crt`, and say why `kubectl create secret tls` cannot be used.
- Configure a `Gateway` listener with `mode: MUTUAL`, and name the alternative `-cacert` secret layout.
- Recognise what a client without a valid certificate observes, and why it is not an HTTP status.
- Explain why a misconfigured `MUTUAL` gateway fails open, and confirm enforcement from the proxy rather than from a successful request.
- State what a verified client certificate does and does not establish, and where the remaining decision belongs.

## Before you start

You need [Module 1](../module-01/course.md): `credentialName`, the secret living in the gateway pod's namespace, the `https` port name, SNI selecting the listener, and reaching the gateway through `port-forward` on `kind`. This module changes the mode and the secret contents; everything else is the same.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile, including `istio-ingressgateway` in `istio-system`), plus `istioctl` and `openssl` on your PATH:

- **`mtlsedge-demo`** — injected. `booking-service-v1` (serving `/book`) and `notification-service-v1`.

No `Gateway`, no `VirtualService` and no secret exist. As in [Module 1](../module-01/course.md), `kind` has no load balancer, so the gateway is reached with `kubectl port-forward`.

## Where this fits

Mesh mTLS from [section 010](../../section-010/README.md) and edge mutual TLS look similar and share no machinery. Inside the mesh, istiod's CA issues both certificates, rotation is automatic, and the identities feed `principals` rules. At the edge, your CA issues them, rotation is your problem, and what the identity feeds is up to you. Turning one on says nothing about the other: a gateway can require client certificates while the mesh behind it is fully `PERMISSIVE`, and the reverse.
