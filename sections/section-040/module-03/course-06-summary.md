# Summary

Most hosts at the edge have TLS (Transport Layer Security) ended at the ingress gateway. This module covered the other case: the gateway forwards an encrypted connection without decrypting it, so only the backend it is addressed to can read it. That is TLS passthrough.

## What you learned

Passthrough starts with what a proxy without a key can see. The first message of a TLS handshake, the ClientHello, is sent before any key exists, so anyone on the path can read it. It carries SNI (Server Name Indication), the host name the client wants, in clear text. Everything after the handshake is encrypted. So a passthrough gateway can route on the SNI name and on nothing else. In Envoy, the TLS inspector reads that name without decrypting anything.

The setup has two objects. The `Gateway` server uses `protocol: TLS` and `tls.mode: PASSTHROUGH`, and has no `credentialName`, because the gateway shows no certificate of its own. The `VirtualService` uses a `tls` block that matches on `sniHosts` and sends the stream to the backend's own TLS port. A test must send the SNI name, with `curl --resolve` or a real DNS name.

A `200` proves nothing about the mode. The certificate the client gets does: in passthrough it is the backend's own, with the same fingerprint as the file on the backend. Inside the gateway, the port 443 listener shows an SNI match that leads straight to a cluster, there is no HTTP route for the host, and the access log has no method, path or status code. All three are the mode working.

A broken passthrough setup never sends a `404` or `403`; the connection just ends. An `http` block applies cleanly and `istioctl analyze` stays quiet, but the gateway builds no listener for the host. A mismatch between the `Gateway`'s `hosts` and the `VirtualService`'s `sniHosts` also leaves no listener, and `istioctl analyze` warns with `IST0132`. A request with no SNI name, for example to an IP address, fails with any setup. So read the gateway's listener, not the status code.

One gateway can end TLS for one host and pass another through on the same port, and it picks the server by the SNI name. Passthrough costs every HTTP feature at the gateway, and it buys a session no one in the middle can read. The key facts to remember are these:

- A passthrough server: `protocol: TLS`, `mode: PASSTHROUGH`, no `credentialName`, and a `VirtualService` `tls` block with `sniHosts`.
- For a passthrough host the gateway loses path routing, header changes, retries, HTTP metrics and request-level authorization.
- Choose passthrough only when the backend needs the original TLS session. Otherwise end TLS at the gateway: `SIMPLE` for the public, `MUTUAL` for known clients, with the Secret in the gateway's own namespace.
- `AUTO_PASSTHROUGH` is for gateways between clusters, not for ordinary ingress.

In short: a passthrough gateway reads only the SNI name, and the certificate the client gets shows who ended TLS.

<!-- astrona:playground:destroy -->
