# Control Workload Certificates: Plug-In CA And Lifetime

Mutual TLS (mTLS) needs a certificate for every workload. Istio issues them itself: `istiod`, the Istio control plane, runs a certificate authority (CA) that signs a certificate for each workload. Out of the box, `istiod` generates its own root certificate and keeps no link to any other trust. That is fine for a demo. In a company, the security team usually wants workload certificates to chain to the corporate root, and wants to know how long a certificate lives and when it is replaced.

This module covers both controls. You decide which CA signs the workload certificates, and you decide how long they are valid.

This module answers the question in three parts. **The Certificate Authority In Istiod** shows which CA signs today, where its certificate comes from, and what a workload certificate contains. **Plug In Your Own CA** builds a root and an intermediate CA, supplies them to `istiod` in the `cacerts` Secret, and proves the chain. **Lifetime And Rotation** covers the default and maximum lifetime, the renewal point, and the per-workload setting. A short summary closes the module.

## Learning objectives

After this module you can:

- Name the CA that signs workload certificates by default and the identity a certificate carries.
- Create the `cacerts` Secret with its four required files and make `istiod` use it.
- Verify a workload certificate against a chain with `openssl`.
- State the default workload certificate lifetime and the point where a proxy renews it.
- Shorten the lifetime of one workload with a pod annotation.

## Before you start

You need three terms. A **root certificate** is a self-signed certificate that other certificates chain to. An **intermediate certificate** is a CA certificate signed by the root, so that the root key can stay offline. A **certificate chain** is the list of certificates from a workload up to the root. A verifier trusts the chain if it ends in a root that it already trusts.

You need `openssl` on your own machine. Your playground is a `kind` cluster with **Istio 1.30.5** installed with Helm. In the namespace **`starfleet`**:

| Workload | Its role in this module |
| --- | --- |
| `probe` | **The workload whose certificate you read.** An HTTP echo server on port `8000`, service account `probe` |
| `shuttle` | A client pod. Its `istio-proxy` container has `openssl`, so you read the `probe` chain from there |

A `PeerAuthentication` in `STRICT` mode is in place. `istiod` uses its default self-signed CA: there is **no `cacerts` Secret yet**.

Launch your playground now and keep it running while you read:

<!-- astrona:playground -->

## Helpers for your terminal

Paste this into each new terminal. It saves each certificate that the `probe` sidecar presents as `proxy-cert-1.pem`, `proxy-cert-2.pem` and so on, in the current directory:

```sh
chain() {
  kubectl exec -n starfleet deploy/shuttle -c istio-proxy -- \
    openssl s_client -showcerts -connect probe.starfleet:8000 </dev/null 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/{n++; f=1} f{print > ("proxy-cert-" n ".pem")} /END CERTIFICATE/{f=0}'
}
```

`proxy-cert-1.pem` is the certificate of the `probe` workload. Run `chain` after every change, and wait until `shuttle` and `probe` show `2/2` in `kubectl get pods -n starfleet`.
