# Wrap-Up: Client Certificates At The Edge

You have finished every part and every lab in this module. Before you move on, look back at what you learned, check yourself, and remove the playground.

## What you learned

This module was about making the ingress gateway (the Envoy proxy that accepts traffic from outside the cluster) check the client's certificate as well as sending its own.

**From [Create A CA And Certificates With OpenSSL](./course-01-issue-the-fleet-badges.md):**

- A certificate ties a name to a public key and carries a signature. A certificate authority (CA) is the key pair that signs certificates.
- Signing a certificate only says "this key belongs to this name". The CA decides who can connect, at the moment it signs.
- `openssl req -x509` makes a self-signed CA. `openssl req` makes a signing request, and `openssl x509 -req` signs it with the CA's key.
- The server certificate needs the host name in the CN and in the SAN. The gateway does not check the name in the client certificate.
- `ca.key` never leaves your machine. `ca.crt` goes into the gateway's secret.

**From [Configure A MUTUAL TLS Gateway](./course-02-make-the-gate-ask-for-a-badge.md):**

- The secret for `MUTUAL` holds `tls.crt`, `tls.key` and `ca.crt`. `kubectl create secret tls` cannot add `ca.crt`, so use `kubectl create secret generic` with `--from-file=name=path`.
- The secret lives in `istio-ingress`, the namespace of the gateway pod.
- `tls.mode: MUTUAL` plus `credentialName` switches on the client certificate check. The `VirtualService` does not change.
- A client without a certificate gets `000` and curl exit code `56`: the gateway closes the connection during TLS, and no HTTP is ever sent. The refused handshake also restarts the port forward, so the next request can get `exit=7` for a few seconds.

**From [Reject Untrusted Client Certificates And Prove It](./course-03-turn-away-strangers-and-prove-it.md):**

- A client certificate from another CA is refused exactly like no certificate at all.
- With the gateway's `connection` logger at `debug` (`istioctl proxy-config log`), its log shows `PEER_DID_NOT_RETURN_A_CERTIFICATE` for no certificate and `CERTIFICATE_VERIFY_FAILED` for a certificate from another CA. The access log has no line for a refused handshake.
- A `MUTUAL` gateway whose secret has no CA leaves the `-cacert` row `WARMING` and refuses everyone, with exit `35`. `istioctl analyze` does not warn about it.
- `istioctl proxy-config secret` shows the server certificate and the CA as `kubernetes://<name>` and `kubernetes://<name>-cacert`. Both must be `ACTIVE`.
- `requireClientCertificate: true` on the `443` listener shows that a client certificate is required.
- `000` means the connection was refused, `401` or `403` means the request was refused, and `404` means nothing refused anything.

**From [The Separate CA Secret And What A Client Certificate Proves](./course-04-two-secret-layouts-and-what-a-badge-proves.md):**

- The split layout puts `tls.crt` and `tls.key` in the secret named in `credentialName`, and `ca.crt` in a second secret named `<credentialName>-cacert`.
- A checked client certificate says who signed for the client, not what the client may do. Decide that in the app (with `X-Forwarded-Client-Cert`) or with an `AuthorizationPolicy` at the gateway.
- `MUTUAL` at the gateway and mesh mTLS are separate. Turning one on does nothing to the other.

## The graded labs

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Require Client Certificates At The Edge](./labs/lab-01/README.md) | Configure A MUTUAL TLS Gateway | build the three-key secret and a `MUTUAL` gateway that refuses clients without a certificate |
| [Fix The Trusted CA In A MUTUAL Gateway](./labs/lab-02/README.md) | Reject Untrusted Client Certificates And Prove It | find a gateway that trusts the wrong CA, and fix it so only the right client certificates are accepted |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Why can you not build the secret for a <code>MUTUAL</code> gateway with <code>kubectl create secret tls</code>?</summary>

It only takes one certificate and one key. It has no flag for the CA, and without `ca.crt` the gateway has nothing to check client certificates against. Use `kubectl create secret generic` with `--from-file=tls.crt=...`, `--from-file=tls.key=...` and `--from-file=ca.crt=...`, or the split layout with a `-cacert` secret.
</details>

<details>
<summary>2. Your <code>Gateway</code> is in <code>starfleet</code>, and the gateway pod runs in <code>istio-ingress</code>. Where does the secret go?</summary>

In `istio-ingress`. The gateway reads `credentialName` from its own namespace only.
</details>

<details>
<summary>3. A client without a certificate calls the gateway. What does curl show, and why is there no <code>403</code>?</summary>

`000` and exit code `56` (some curl builds say `35`). The gateway closes the connection during the TLS handshake, before any HTTP request exists, so there is nothing to put a status code on.
</details>

<details>
<summary>4. A client sends a certificate from another CA. How does that look different from no certificate at all?</summary>

From the client's side, it does not: both get `000` and exit code `56`. On the gateway's side, set the `connection` logger to `debug` and read the log: no certificate shows `PEER_DID_NOT_RETURN_A_CERTIFICATE`, a certificate from another CA shows `CERTIFICATE_VERIFY_FAILED`.
</details>

<details>
<summary>5. Your test with a good client certificate returns <code>200</code>. Is the client certificate check on?</summary>

You do not know yet. Read `istioctl proxy-config secret` on the gateway (the `-cacert` row must be `ACTIVE`) and look for `requireClientCertificate: true` on the `443` listener. Then test without a client certificate: it must fail.
</details>

<details>
<summary>6. In the split layout, <code>credentialName</code> is <code>partner-gate</code>. What is the second secret called, and which key does it hold?</summary>

`partner-gate-cacert`, with the key `ca.crt`, in the gateway pod's namespace.
</details>

<details>
<summary>7. Five partners hold client certificates from your CA. How does the gateway decide which of them may call <code>/admin</code>?</summary>

It does not, with `MUTUAL` alone. The certificate check only proves your CA signed the certificate. Add an `AuthorizationPolicy` at the gateway, or let the app read the certificate details from `X-Forwarded-Client-Cert`.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-02
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-040-02-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

The certificates in your `certs/` folder stay on your machine. Delete them with `rm -r certs` when you no longer need them.

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *The gateway checks who signed the client certificate, before any request is sent; what that client may do is still your decision.*
