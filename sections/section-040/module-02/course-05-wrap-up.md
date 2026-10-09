# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and every mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about making the spaceport arrival gate (the ingress gateway) check the visitor's badge as well as showing its own.

**From [Issue The Fleet's Badges](./course-01-issue-the-fleet-badges.md):**

- A certificate is an ID badge: a name, a public key and a signature. A certificate authority (CA) is the badge office that signs badges.
- Signing a badge only says "this key belongs to this name". The CA decides who can connect, at the moment it signs.
- `openssl req -x509` makes a self-signed CA. `openssl req` makes a signing request, and `openssl x509 -req` signs it with the CA's key.
- The server badge needs the host name in the CN and in the SAN. The client badge's name is not checked by the gate.
- `ca.key` never leaves your machine. `ca.crt` goes into the gate's secret.

**From [Make The Gate Ask For A Badge](./course-02-make-the-gate-ask-for-a-badge.md):**

- The secret for `MUTUAL` holds `tls.crt`, `tls.key` and `ca.crt`. `kubectl create secret tls` cannot add `ca.crt`, so use `kubectl create secret generic` with `--from-file=name=path`.
- The secret lives in `istio-ingress`, the namespace of the gateway pod.
- `tls.mode: MUTUAL` plus `credentialName` switches on the badge check. The `VirtualService` does not change.
- A visitor without a badge gets `000` and curl exit code `56`: the gate hangs up during TLS, and no HTTP is ever sent. The refused handshake also restarts the port forward, so the next signal can get `exit=7` for a few seconds.

**From [Turn Away Strangers And Prove It](./course-03-turn-away-strangers-and-prove-it.md):**

- A badge from another CA is refused exactly like no badge at all.
- With the gate's `connection` logger at `debug` (`istioctl proxy-config log`), its log shows `PEER_DID_NOT_RETURN_A_CERTIFICATE` for no badge and `CERTIFICATE_VERIFY_FAILED` for a badge from another CA. The access log has no line for a refused handshake.
- A `MUTUAL` gate whose secret has no CA leaves the `-cacert` row `WARMING` and refuses everyone, with exit `35`. `istioctl analyze` does not warn about it.
- `istioctl proxy-config secret` shows the server badge and the CA as `kubernetes://<name>` and `kubernetes://<name>-cacert`. Both must be `ACTIVE`.
- `requireClientCertificate: true` on the `443` listener shows that a badge is demanded.
- `000` means the connection was refused, `401` or `403` means the request was refused, and `404` means nothing refused anything.

**From [Two Secret Layouts And What A Badge Proves](./course-04-two-secret-layouts-and-what-a-badge-proves.md):**

- The split layout puts `tls.crt` and `tls.key` in the secret named in `credentialName`, and `ca.crt` in a second secret named `<credentialName>-cacert`.
- A checked badge says who signed for the visitor, not what the visitor may do. Decide that in the app (with `X-Forwarded-Client-Cert`) or with an `AuthorizationPolicy` at the gate.
- `MUTUAL` at the gate and mesh mTLS are separate. Turning one on does nothing to the other.

## Your missions

You proved each skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Require Client Certificates At The Edge](./labs/lab-01/README.md) | Make The Gate Ask For A Badge | build the three-key secret and a `MUTUAL` gateway that refuses clients without a badge |
| [Fix The Gate's Trusted Badge Office](./labs/lab-02/README.md) | Turn Away Strangers And Prove It | find a gate that trusts the wrong CA, and fix it so only the right badges get in |

If you skipped one, go back to it now. Each mission is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Why can you not build the secret for a <code>MUTUAL</code> gateway with <code>kubectl create secret tls</code>?</summary>

It only takes one certificate and one key. It has no flag for the CA, and without `ca.crt` the gate has nothing to check visitors' badges against. Use `kubectl create secret generic` with `--from-file=tls.crt=...`, `--from-file=tls.key=...` and `--from-file=ca.crt=...`, or the split layout with a `-cacert` secret.
</details>

<details>
<summary>2. Your <code>Gateway</code> is in <code>starfleet</code>, and the gateway pod runs in <code>istio-ingress</code>. Where does the secret go?</summary>

In `istio-ingress`. The gateway reads `credentialName` from its own namespace only.
</details>

<details>
<summary>3. A visitor without a badge calls the gate. What does curl show, and why is there no <code>403</code>?</summary>

`000` and exit code `56` (some curl builds say `35`). The gate hangs up during the TLS handshake, before any HTTP request exists, so there is nothing to put a status code on.
</details>

<details>
<summary>4. A visitor shows a badge from another CA. How does that look different from no badge at all?</summary>

From the visitor's side, it does not: both get `000` and exit code `56`. On the gate's side, set the `connection` logger to `debug` and read the log: no badge shows `PEER_DID_NOT_RETURN_A_CERTIFICATE`, a badge from another CA shows `CERTIFICATE_VERIFY_FAILED`.
</details>

<details>
<summary>5. Your test with a good badge returns <code>200</code>. Is the badge check on?</summary>

You do not know yet. Read `istioctl proxy-config secret` on the gateway (the `-cacert` row must be `ACTIVE`) and look for `requireClientCertificate: true` on the `443` listener. Then test without a badge: it must fail.
</details>

<details>
<summary>6. In the split layout, <code>credentialName</code> is <code>partner-gate</code>. What is the second secret called, and which key does it hold?</summary>

`partner-gate-cacert`, with the key `ca.crt`, in the gateway pod's namespace.
</details>

<details>
<summary>7. Five partners hold badges from your CA. How does the gate decide which of them may call <code>/admin</code>?</summary>

It does not, with `MUTUAL` alone. The badge check only proves your CA signed the badge. Add an `AuthorizationPolicy` at the gate, or let the app read the badge details from `X-Forwarded-Client-Cert`.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-02
```

If `astrona list` also showed a mission, remove it the same way, for example:

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

> *The gate checks who signed the visitor's badge, before any request is sent; what that visitor may do is still your decision.*
