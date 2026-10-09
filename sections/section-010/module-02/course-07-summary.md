# Summary

Every workload in the mesh has a certificate, but having one does not mean it must be used. This module was about the object that makes mTLS required on the receiving side, `PeerAuthentication`, and the `DestinationRule` setting that decides what the sending side uses.

## What you learned

mTLS (mutual Transport Layer Security) means both sides present a certificate signed by `istiod`, and the connection between them is encrypted. The name in the certificate is a SPIFFE ID built from the namespace and the service account. With no policy at all, every workload is `PERMISSIVE`: it accepts mTLS and plain text. Auto mTLS makes callers with a sidecar use mTLS by themselves, so a `200` proves nothing. Only the `X-Forwarded-Client-Cert` header on the receiving side shows that a request carried the caller's identity.

The mode decides which filter chains the receiving sidecar's inbound listener holds. `PERMISSIVE` keeps an mTLS chain and a plain-text chain side by side. `STRICT` keeps only the mTLS chain, so a caller without a sidecar gets `000` and `curl` exit code `56`, and the receiver's access log shows `NR filter_chain_not_found`. That reset points at `PeerAuthentication`; a `403` points at an authorization rule. `DISABLE` turns mTLS off for every caller, and `UNSET` passes the decision to the next wider policy.

Scope is not a field. A policy in the root namespace, `istio-system`, with no `selector` is mesh-wide; in any other namespace with no `selector` it is namespace-wide; with a `selector` it covers only the matching pods. The narrowest policy that covers a pod decides alone, so a `PERMISSIVE` namespace policy beats a `STRICT` mesh policy. `portLevelMtls` is narrower still: it sets the mode for single ports inside a workload policy, and its key is the container port, not the Service port.

A policy in the wrong place applies without an error, so you prove it twice: with real traffic, and then with `istioctl`. `istioctl x describe pod` shows the mode that won and every policy that covers the pod. `istioctl proxy-config listener` on port `15006` shows the filter chains themselves.

`PeerAuthentication` only controls what a workload accepts. What callers send is set by `trafficPolicy.tls.mode` in a `DestinationRule`, and once that field is set, auto mTLS no longer decides for that host. The key facts to remember are these:

- With no policy, the mode is `PERMISSIVE`. Under `STRICT`, a caller without a sidecar gets a reset connection (`000`, exit code `56`), not an HTTP error.
- The narrowest policy wins and decides alone: port, then workload, then namespace, then mesh.
- `portLevelMtls` needs a `selector`, and its key is the container port (`8080` for the probe). A Service port as the key is accepted and silently does nothing.
- `tls.mode: DISABLE` in a caller's `DestinationRule` against a `STRICT` server gives `503 UC` in the caller's access log. Fix the `DestinationRule`, not the server.

In short: a `PeerAuthentication` decides what a workload accepts, at the narrowest scope that covers it, and a `DestinationRule` decides what callers send. Both sides must agree.

<!-- astrona:playground:destroy -->
