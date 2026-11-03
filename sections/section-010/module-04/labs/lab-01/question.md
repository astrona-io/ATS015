---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed. `istiod` runs with its default self-signed CA and no Secret named `cacerts` exists. The namespace `ca-demo` has sidecar injection on and a `PeerAuthentication` in `STRICT` mode. It runs:

* `shuttle`: a client pod. Its `istio-proxy` container has `openssl`.
* `probe-long`: an echo server, Service `probe-long`, port `8000`.
* `probe-short`: an echo server, Service `probe-short`, port `8000`.

You have `openssl` on your own machine.

1. Create a root CA and an intermediate CA with `openssl`. The intermediate must be a CA certificate signed by the root.
2. Make `istiod` sign workload certificates with the intermediate CA, by creating the Secret `cacerts` in `istio-system` with the four keys `ca-cert.pem`, `ca-key.pem`, `root-cert.pem` and `cert-chain.pem`.
3. Make sure every workload in `ca-demo` holds a certificate from the new CA.
4. Give `probe-short` a certificate lifetime of two hours. Leave `probe-long` at the default.

The result, read from the certificate that each workload's sidecar presents:

| Workload | Expected |
| --- | --- |
| `probe-long` | The certificate verifies against the intermediate and root in `cacerts`. It does not expire within four hours |
| `probe-short` | The certificate verifies against the same CA. It expires within four hours |

Constraints:

* Do not change the `PeerAuthentication` or the Services.
* Do not put the root private key into the cluster.
* Do not use `istioctl install` to change the CA.

The grader reads the Secret, reads the certificate chains that the two sidecars present, and checks them with `openssl`, so the setup has to work, not merely exist.
