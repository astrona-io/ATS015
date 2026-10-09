# Summary

The ingress gateway is the Envoy proxy that accepts traffic from outside the cluster. This module made it check the client's certificate as well as sending its own, so that only callers with a certificate from your CA can connect at all.

## What you learned

Everything starts with the **certificate authority** (CA). A certificate ties a name to a public key and carries the signature of the CA that issued it. Signing only says "this key belongs to this name", so the CA decides who can connect at the moment it signs. You made a CA with `openssl req -x509`, and signed a server certificate and a client certificate with `openssl x509 -req`. The server certificate needs the host name in the CN and in the SAN. The gateway does not check the name in a client certificate, only the signature. `ca.key` never leaves your machine, and `ca.crt` goes to the gateway.

The gateway reads its certificates from a secret in the namespace of the gateway pod, `istio-ingress`. For `MUTUAL` TLS, that secret holds three keys: `tls.crt`, `tls.key` and `ca.crt`. `kubectl create secret tls` cannot add the CA, so you build it with `kubectl create secret generic` and `--from-file=name=path`. In the split layout, `credentialName` names a normal TLS secret, and the CA sits under `ca.crt` in a second secret called `<credentialName>-cacert`. In the `Gateway`, `tls.mode: MUTUAL` plus `credentialName` switches the check on, and the `VirtualService` does not change.

The check happens in the TLS handshake, before any HTTP is sent. So a client without a certificate, and a client with a certificate from another CA, both get no status code: curl shows `000` and exit code `56` (some builds say `35`). The access log has no line for a refused handshake. To see the reason, set the gateway's `connection` logger to `debug`: it logs `PEER_DID_NOT_RETURN_A_CERTIFICATE` or `CERTIFICATE_VERIFY_FAILED`.

A `200` with a good certificate proves nothing about other clients. The real proof sits in the gateway's own proxy, and these are the key facts to remember:

- `istioctl proxy-config secret` shows `kubernetes://<name>` and `kubernetes://<name>-cacert`. Both must be `ACTIVE`; a `WARMING` CA means the gateway refuses every client, and `istioctl analyze` does not warn about it.
- `requireClientCertificate: true` on the `443` listener shows that a client certificate is required.
- `000` means the connection was refused, `401` or `403` means the request was refused, and `404` means nothing refused anything.

Finally, a checked client certificate says who signed for the client, not what the client may do. Authentication says who; authorization decides what. Decide what each caller may do in the app, with `X-Forwarded-Client-Cert`, or with an `AuthorizationPolicy` at the gateway. `MUTUAL` at the gateway and mesh mTLS are also separate: turning one on does nothing to the other.

In short: the gateway checks who signed the client certificate before any request is sent, and what that client may do is still your decision.

<!-- astrona:playground:destroy -->
