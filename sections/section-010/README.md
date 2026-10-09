# Workload Identity And Mutual TLS

Every security rule in this course eventually matches on one string — a workload's mesh identity. This section is where that string comes from, how you make a workload prove it, and how to turn the proof on in a cluster that is already running without breaking the callers who were not ready.

Three modules, in dependency order. Module 1 opens a certificate and reads the identity out of it, because a policy written against an identity you assumed rather than checked is the most common failure in the whole domain. Module 2 makes that identity mandatory with `PeerAuthentication`, at each of its three scopes. Module 3 is the procedure for doing so on a live namespace: measure, write down, mesh, enforce.

**Curriculum item covered:** Configuring Authentication (mTLS, JWT)

---

## What You Will Master

- The SPIFFE URI form `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`, and that identity comes from the service account rather than the pod.
- Reading a workload certificate's SAN with `istioctl proxy-config secret` and `openssl`, and converting it into a policy `principals` value.
- Certificate lifetime, automatic rotation by `istio-agent`, and what `meshConfig.trustDomain` breaks when it changes.
- `PeerAuthentication` at mesh, namespace and workload scope, and the narrowest-wins precedence between them.
- `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET`, and the connection-reset failure signature a `STRICT` server produces.
- Reading `connection_security_policy` off `istio_requests_total` to prove no plaintext remains before enforcing.
- `portLevelMtls` exceptions on container ports, and why a client-side `DestinationRule` with `tls.mode: DISABLE` breaks a `STRICT` server with `503 UC`.
- Reading the mode a pod really uses with `istioctl x describe pod` and its inbound listener.

---

<!-- astrona:playground -->