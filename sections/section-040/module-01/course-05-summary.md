# Summary

Requests from outside the cluster reach the mesh through the ingress gateway, an Envoy proxy at the edge of the mesh. This module put that gateway behind HTTPS: the gateway holds a certificate you supply, terminates TLS, and sends the decrypted request on to `bridge` inside the mesh.

## What you learned

A client trusts a certificate only if a certificate authority (CA) it trusts signed it, and only if the host name it asked for is in the certificate's SAN (subject alternative name). You made a small CA and a server certificate with `openssl`, and you kept the private key unencrypted with `-nodes`, because the gateway starts with nobody there to type a password.

The gateway finds its certificate through `credentialName`, a bare Secret name. Istio looks it up in the namespace of the gateway **pod**, `istio-ingress` here, and never in the namespace where the `Gateway` object lives. `istiod` reads the Secret and pushes it to the gateway's Envoy over SDS (Secret Discovery Service), so nothing is mounted as a file. Because of SDS, updating the Secret in place rotates the certificate on a running gateway, with no restart and no change to the `Gateway`.

A `SIMPLE` TLS server needs `protocol: HTTPS`, the host names in `hosts`, `tls.mode: SIMPLE` and `credentialName`, and its `selector` must match the gateway pod's labels. The `VirtualService` behind it is the same as for plain HTTP, with the gateway named in `gateways:`. A second server on port `80` with `tls.httpsRedirect: true` answers every plain HTTP request with a `301` to the `https://` address and routes nothing.

The gateway reads two names at two different times. It picks the server and its certificate by the SNI (Server Name Indication) in the handshake, before decryption, and it picks the route by the `Host` header after decryption. So a wrong host name fails the handshake, while a wrong route gives a `404` on a working connection. You prove which certificate answered with `curl -v` on the client side and `istioctl proxy-config secret` on the gateway side.

When TLS fails, there is no HTTP status, so curl's exit code is the first clue. The key facts to remember are these:

- Exit `7` means curl cannot connect, exit `35` means the gateway closed the handshake, and exit `60` means the client does not trust the certificate.
- On a `35`, run `istioctl proxy-config secret` on the gateway. A Secret row that is missing or `WARMING` means the certificate never arrived; `istioctl analyze` reports the same thing as `IST0101`.
- If the Secret is `ACTIVE`, compare the SNI with the `Gateway`'s `hosts`. Test with `--resolve` and the real host name, never with an IP address.

In short: keep the Secret in the gateway pod's namespace, test with the real host name, and read the exit code before you change any YAML.

<!-- astrona:playground:destroy -->
