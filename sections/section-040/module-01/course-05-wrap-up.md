# Wrap-Up: Mission Debrief

Well flown, astronaut. You have put the arrival gate behind HTTPS, redirected plain callers, replaced a certificate in flight, and read a failed handshake. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about terminating TLS at the ingress gateway: the gate holds the certificate, opens the sealed signal, and sends it on inside the mesh.

**From [Give The Gate Its Certificate](./course-01-give-the-gate-its-certificate.md):**

- A certificate is a ship's ID papers; a certificate authority (CA) signs them. A client trusts a certificate only if a CA it trusts signed it, and the host name is in the SAN.
- `openssl req -x509` makes a CA; `openssl req` plus `openssl x509 -req` makes a server certificate the CA signs. `-nodes` keeps the private key unencrypted, which the gateway needs.
- `credentialName` is a bare Secret name, looked up in the namespace of the **gateway pod** (`istio-ingress`), never where the `Gateway` lives.
- `istiod` reads the Secret and pushes it to the gateway's Envoy over SDS. Nothing is mounted as a file.
- `kubectl create secret tls` makes exactly the keys Istio reads: `tls.crt` and `tls.key`.

**From [Open The HTTPS Door](./course-02-open-the-https-door.md):**

- A `SIMPLE` TLS server needs `protocol: HTTPS`, the host names in `hosts`, `tls.mode: SIMPLE` and `credentialName`. The `selector` must match the gateway pod's labels (`istio: ingress` for the Helm chart).
- The `VirtualService` is the same as for HTTP: it names the host and the gateway in `gateways:`.
- The gateway picks the door and its certificate by the **SNI** in the handshake, and the route by the `Host` header after. `curl --resolve` sets both.
- `curl -v` shows the certificate the client got. `istioctl proxy-config secret` shows the certificates the gateway holds; `ACTIVE` means delivered.
- Without the right CA, curl stops with exit code `60`.

**From [Redirect And Rotate](./course-03-redirect-and-rotate.md):**

- A port `80` server with `tls.httpsRedirect: true` answers every plain HTTP request with `301` to the `https://` address, and routes nothing.
- Updating the Secret in place (`--dry-run=client -o yaml | kubectl apply -f -`) rotates the certificate on a running gateway, with no restart and no change to the `Gateway`.

**From [When The Handshake Fails](./course-04-when-the-handshake-fails.md):**

- A Secret in the wrong namespace: the `Gateway` is accepted, the old door keeps working for a few seconds and then the handshake fails (exit `35`), `proxy-config secret` shows `WARMING`, and `istioctl analyze` reports `IST0101`.
- A host name no door lists: the handshake fails with exit `35`, even with `-k`. You never get a `404` for a wrong SNI.
- When TLS fails there is no HTTP status. Read curl's exit code: `7` cannot connect, `35` the gate cut the handshake, `60` not trusted. A `35` does not say why, so check `proxy-config secret` next.
- A plain HTTP signal to a port with no door gets an empty reply (exit `52`).

## Your missions

You proved each skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Serve HTTPS At The Ingress Gateway](./labs/lab-01/README.md) | Redirect And Rotate | put a certificate where the gateway reads it, serve HTTPS and redirect HTTP |
| [Repair The Gate's Certificate](./labs/lab-02/README.md) | When The Handshake Fails | find a Secret on the wrong planet and a wrong host name, and fix both |

If you skipped one, go back to it now. Each mission is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Your <code>Gateway</code> lives in <code>starfleet</code>. In which namespace must its TLS Secret be?</summary>

In the namespace of the gateway **pod**: `istio-ingress` in this playground (often `istio-system` with an `istioctl` install). Where the `Gateway` object lives does not matter for the Secret lookup.
</details>

<details>
<summary>2. The <code>Gateway</code> and the Secret both exist, but every HTTPS signal fails. Which command do you run first, and what do you look for?</summary>

`istioctl proxy-config secret deploy/istio-ingress -n istio-ingress`. If the Secret's row is missing or `WARMING`, the gateway never received it: check the Secret's namespace, name and key names. `istioctl analyze` reports the same problem as `IST0101`.
</details>

<details>
<summary>3. curl prints <code>000 exit=35</code>. The Secret is <code>ACTIVE</code>. What do you check?</summary>

The host name. The SNI curl sends must match a host in the `Gateway`'s `hosts`. Test with `--resolve <host>:<port>:127.0.0.1`, not with an IP address in the URL.
</details>

<details>
<summary>4. curl prints <code>000 exit=60</code>. Is the gateway broken?</summary>

No. Exit `60` means the client does not trust the certificate. Give curl the CA that signed it with `--cacert`, or use a certificate from a CA the client already trusts.
</details>

<details>
<summary>5. The handshake works, but the bridge answers <code>404</code>. Which object is wrong?</summary>

The `VirtualService`. TLS is fine, because the seal was opened. Check its `hosts`, its `gateways:` entry and its `match` paths.
</details>

<details>
<summary>6. What goes in the <code>tls</code> block of the port 80 redirect server?</summary>

Only `httpsRedirect: true`. The redirect door needs no certificate, and it routes nothing: every request gets a `301` to `https://`.
</details>

<details>
<summary>7. How do you replace the gateway's certificate without an outage?</summary>

Update the Secret in place, for example `kubectl create secret tls ... --dry-run=client -o yaml | kubectl apply -f -`. `istiod` pushes the new certificate over SDS, and the gateway uses it for new handshakes without a restart.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-01
```

If `astrona list` also showed a mission, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-040-01-02
```

Then check that everything is gone, and delete the test certificates you made:

```sh
astrona list
rm -r certs
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *The gate shows a certificate you supply: keep its Secret in the gateway pod's namespace, test with the real host name, and read curl's exit code when the handshake fails.*
