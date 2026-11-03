# Summary

`istiod` runs a CA that signs one certificate per workload. The sidecar agent creates the key inside the pod, sends a CSR authenticated with the service account token, and receives a certificate whose SAN holds the SPIFFE identity `spiffe://cluster.local/ns/<namespace>/sa/<service account>`. Peers trust each other when their certificates chain to the same root.

By default `istiod` generates a self-signed root and keeps it in the Secret `istio-ca-secret`. A plug-in CA replaces it. You create a root and an intermediate CA outside the cluster, store `ca-cert.pem`, `ca-key.pem`, `root-cert.pem` and `cert-chain.pem` in the Secret `cacerts` in `istio-system`, and restart `istiod` and the workloads. You prove the result with `openssl verify -CAfile` on the workload certificate, read from the sidecar with `openssl s_client`.

Workload certificates live 24 hours by default (`DEFAULT_WORKLOAD_CERT_TTL`), `istiod` grants at most `2160h` (`MAX_WORKLOAD_CERT_TTL`), and a sidecar renews at half of the lifetime (`SECRET_GRACE_PERIOD_RATIO` `0.5`). One workload can request a shorter lifetime with `SECRET_TTL` set through the `proxy.istio.io/config` annotation on its pod template.

The key facts to remember are these:

- `cacerts` needs four keys: `ca-cert.pem`, `ca-key.pem`, `root-cert.pem`, `cert-chain.pem`.
- Only the intermediate key goes into the cluster. The root key stays offline.
- Restart `istiod`, then the workloads, so every pod gets a certificate from the new CA.
- Defaults: 24h lifetime, 2160h maximum, renewal at half life.
- A short lifetime means more frequent signing requests.

In short: control trust with `cacerts`, control exposure with a short lifetime, and prove both by reading the certificate the sidecar presents.

<!-- astrona:playground:destroy -->
