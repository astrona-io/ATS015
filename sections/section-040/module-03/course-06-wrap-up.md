# Wrap-Up: TLS Passthrough

You have finished every part and every lab in this module. Before you move on, look back at what you learned, check yourself, and remove the playground cleanly.

## What you learned

This module was about the ingress gateway forwarding an encrypted connection without decrypting it, so only the backend it is addressed to can decrypt it.

**From [What A Proxy Can See](./course-01-what-a-proxy-can-see.md):**

- The first message of a TLS handshake, the ClientHello, is sent before any key exists, so it is readable. Everything after the handshake is encrypted.
- SNI, the host name in the ClientHello, is sent in clear text. It is the only field a passthrough gateway can route on.
- Envoy's TLS inspector reads SNI and ALPN without decrypting anything.
- `tls-backend` makes its own certificate when its pod starts. Its fingerprint is the proof of "same certificate".

**From [Configure A Passthrough Gateway](./course-02-open-a-gate-that-does-not-decrypt.md):**

- A passthrough server uses `protocol: TLS` and `tls.mode: PASSTHROUGH`, and has no `credentialName`.
- The `VirtualService` uses a `tls` block that matches on `sniHosts` and `port`, never an `http` block.
- `sniHosts` names the same host as the `Gateway`'s `hosts`. The destination port is the backend's own TLS port, here `8443`.
- Test with `--resolve` (or real DNS), so the client sends the SNI name.

**From [Prove Where TLS Ends](./course-03-prove-who-opened-the-envelope.md):**

- A `200` proves nothing about the mode. The certificate the client gets does: in passthrough it is the backend's own, with the same fingerprint as on the backend's disk.
- The gateway's port 443 listener shows an SNI match that leads straight to a cluster, not to an HTTP route.
- The gateway has no HTTP route for a passthrough host, and its access log has no method, path or status code. Both are the mode working.

**From [Troubleshoot A Passthrough Setup](./course-04-when-the-stream-has-nowhere-to-go.md):**

- An `http` block on a passthrough host applies cleanly, `istioctl analyze` stays quiet, and it routes nothing. The connection fails with `000`, and the gateway has no port 443 listener at all.
- When the `Gateway`'s `hosts` and the `VirtualService`'s `sniHosts` disagree, the gateway again has no listener for the SNI name the client sends. Here `istioctl analyze` warns with `IST0132`.
- A request with no SNI name, for example to an IP address, cannot be routed by any passthrough setup.
- A broken passthrough setup never sends a `404` or `403`. Read the gateway's listener, not the status code.

**From [Termination And Passthrough On One Gateway](./course-05-one-gate-two-modes.md):**

- One gateway can end TLS for one host (`SIMPLE` with a Secret in the gateway's namespace) and pass another through, on the same port. It picks the server by the SNI name.
- For a passthrough host the gateway loses path routing, header changes, retries, HTTP metrics and request-level authorization.
- Choose passthrough only when the backend needs the original TLS session. Otherwise end TLS at the gateway: `SIMPLE` for the public, `MUTUAL` for known clients.
- `AUTO_PASSTHROUGH` is for gateways between clusters, not for ordinary ingress.

## Your missions

You practised each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Route An Encrypted Stream By SNI](./labs/lab-01/README.md) | Prove Where TLS Ends | expose a backend through the gateway without decrypting, and prove the backend ended TLS |
| [Fix A Passthrough Gateway That Routes Nothing](./labs/lab-02/README.md) | Troubleshoot A Passthrough Setup | find and fix a passthrough setup that applies cleanly but routes nothing |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Which parts of a TLS connection can a gateway read without the key?</summary>

Only the ClientHello, the client's first message: the TLS version, the cipher list, the SNI name and ALPN. The method, path, headers, body and response are all encrypted.
</details>

<details>
<summary>2. You set <code>protocol: HTTPS</code> and <code>mode: PASSTHROUGH</code>. What is wrong?</summary>

The object says two different things. `HTTPS` means "end TLS here and read the HTTP inside", and `PASSTHROUGH` means "do not decrypt". In Istio 1.30.5 the mode wins and the gateway still passes the traffic through, but the object misleads the next reader. A passthrough server uses `protocol: TLS`.
</details>

<details>
<summary>3. Your passthrough host gives <code>000</code>. <code>kubectl get</code> lists both objects and <code>istioctl analyze</code> is quiet. What do you check first?</summary>

Whether the `VirtualService` uses a `tls` block with `sniHosts`, not an `http` block. With an `http` block, `istioctl proxy-config listener` shows no port 443 listener for the host at all. When it works, the SNI name is in the `MATCH` column.
</details>

<details>
<summary>4. You get <code>200</code> through the gateway. How do you prove the gateway did not end TLS?</summary>

Read the certificate the client gets, for example with `openssl s_client -servername <host>`. In passthrough it is the backend's own certificate, with the same fingerprint as on the backend. Also, the gateway has no HTTP route for that host.
</details>

<details>
<summary>5. <code>istioctl proxy-config routes</code> shows no route for your passthrough host. Do you fix it?</summary>

No. A passthrough host has no HTTP route, because the gateway never reads HTTP for it. A missing route is only a problem for a host the gateway ends TLS for.
</details>

<details>
<summary>6. A backend checks its clients' certificates itself. Which gateway mode do you choose?</summary>

`PASSTHROUGH`. Only then does the backend get the client's real certificate. A gateway that ends TLS can pass on only a summary of it in a header.
</details>

<details>
<summary>7. Your team wants path-based routing and HTTP metrics for a host. Can that host use passthrough?</summary>

No. Path routing, HTTP metrics, retries and header changes all need the gateway to read the request. End TLS at the gateway for that host instead.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-03
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-040-03-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can also delete the files `starfleet.key` and `starfleet.crt` you made on your own machine. You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *Passthrough means the gateway reads only the SNI name: route with `sniHosts`, prove it with the backend's own certificate, and accept that every HTTP feature stays behind.*
