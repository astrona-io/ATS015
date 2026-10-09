# Securing Edge Traffic With TLS

Inside the mesh, Istio issues both certificates and mutual TLS happens without being asked for. At the edge none of that holds: the caller is a browser or an external system, the certificate must be one that caller already trusts, and you supply it.

Four modules. The first three cover one `Gateway` TLS mode each. Module 1 is `SIMPLE` — ordinary server-side HTTPS, and the namespace rule that makes almost everyone's first attempt fail. Module 2 is `MUTUAL`, requiring a client certificate signed by a CA you nominate. Module 3 is `PASSTHROUGH`, where the gateway forwards an encrypted stream it cannot read and routes on SNI alone. Module 4 looks at signals that leave the mesh: the app sends plain HTTP, and its own sidecar adds the TLS seal on the way out. This is called TLS origination.

**Curriculum item covered:** Securing Edge Traffic with TLS

---

## What You Will Master

- `credentialName` naming a Secret in the **gateway pod's** namespace (`istio-ingress` in the playgrounds, `istio-system` with an `istioctl` install), not the application's.
- The port block that a TLS listener depends on: `protocol: HTTPS` on `443`. The port `name` is only a label.
- `kubectl create secret tls` for `SIMPLE`, and why `MUTUAL` needs `create secret generic` with `tls.crt`, `tls.key` **and** `ca.crt`.
- `tls.httpsRedirect` on a port-80 listener, and why the `tls` block belongs there at all.
- What a client rejected during a TLS handshake observes, and why it is never an HTTP status.
- That a successful request does not prove a `MUTUAL` gateway checks client certificates: read the `-cacert` secret and `requireClientCertificate` from the gateway's proxy. A `MUTUAL` gateway with no CA turns everyone away.
- `protocol: TLS` with `mode: PASSTHROUGH`, and routing with a `VirtualService` `tls` block matching `sniHosts`.
- Everything passthrough gives up at the edge — path and header routing, rewrites, L7 telemetry, and every authorization rule that mentions methods, paths or hosts.
- Proving which end terminated TLS by reading the certificate the handshake actually returned.
- A `ServiceEntry` port `80` with `targetPort: 443` and a `DestinationRule` with `tls.mode: SIMPLE`, so the sidecar seals an app's plain `http://` call to an outside service.
- `subjectAltNames` to check an outside server's certificate name, and the three failures `400`, `WRONG_VERSION_NUMBER` and `CERTIFICATE_VERIFY_FAILED`.

---

<!-- astrona:playground -->