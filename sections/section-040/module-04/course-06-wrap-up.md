# Wrap-Up

You have finished every part and the lab in this module. Before you move on, look back at what you learned, check yourself, and remove the playground.

## What you learned

This module was about letting the sidecar proxy (Envoy) start TLS for requests to a service outside the cluster, so the app can speak plain HTTP and the mesh can still read every request.

**From [Who Starts The TLS Connection](./course-01-who-seals-the-signal.md):**

- When the app starts its own TLS connection, the sidecar sees only the destination address, the SNI name, byte counts and whether the connection worked. The access log shows `"- - -"` and status `0`.
- TLS can be started by the app, by its own sidecar (TLS origination) or by an egress gateway.
- The app must call `http://` for origination to work.
- `tls.mode` in a `DestinationRule` describes what the client side sends: `DISABLE`, `SIMPLE`, `MUTUAL` or `ISTIO_MUTUAL`.

**From [Originate TLS With A ServiceEntry And A DestinationRule](./course-02-chart-the-planet-and-seal-the-signal.md):**

- The `ServiceEntry` adds `httpbin.org` with port `80` (`HTTP`, `targetPort: 443`) and port `443` (`HTTPS`). On its own, it sends plain HTTP to port `443`, and the server answers `400`.
- The `DestinationRule` puts `tls.mode: SIMPLE` and `sni` under `portLevelSettings` for port `80`. Then httpbin.org reports `"url": "https://httpbin.org/get"`.
- The app's own `https://` calls keep working, because port `443` is not touched.
- `istioctl proxy-config cluster ... --port 80 -o json` shows `envoy.transport_sockets.tls` and the `sni` name on the port where the sidecar starts TLS.

**From [Verify The Server Certificate Name](./course-03-check-the-planets-id-card.md):**

- `subjectAltNames` lists the names the server's certificate must carry. A wrong name fails with `503 URX,UF` and `CERTIFICATE_VERIFY_FAILED`.
- `sni` is only the name the sidecar asks for. A wrong `sni` was not caught at httpbin.org.
- Without `caCertificates`, the sidecar trusts the usual public certificate authorities.

**From [Diagnose TLS Origination Failures](./course-04-a-seal-on-the-wrong-channel.md):**

- Without `targetPort`, the sidecar sends a TLS handshake to port `80`, and the call fails with `503 URX,UF` and `WRONG_VERSION_NUMBER`.
- `400` means TLS is missing, `WRONG_VERSION_NUMBER` means TLS went to the wrong port, and `CERTIFICATE_VERIFY_FAILED` means the server's certificate does not match.

**From [Add A Timeout And Mutual TLS To An External Service](./course-05-use-what-you-won.md):**

- A `VirtualService` with `timeout: 2s` turns a slow outside HTTPS call into `504 UT`. That only works because the sidecar reads the plain HTTP request.
- `MUTUAL` adds a client certificate, from a secret in the calling workload's namespace (`credentialName`) or from files in the sidecar container.

## Your missions

| Lab | What you proved | After part |
| --- | --- | --- |
| [Originate TLS To An External Service Lab](./labs/lab-01/question.md) | Make the `shuttle` pod's sidecar originate TLS for plain `http://` requests to `httpbin.org` and check the server's name | Verify The Server Certificate Name |

## Check yourself

Answer these without looking back. If one is hard, reread the part it comes from.

1. An app calls `https://api.example.com`. Which four things can its sidecar still see?
2. What does the `"url"` field in httpbin.org's answer tell you, and why is it good proof?
3. Which two settings make TLS origination work, and which one decides *where* and which one *how* the sidecar connects?
4. You applied the `ServiceEntry` with `targetPort: 443` but no `DestinationRule`. What does the server answer, and why?
5. Why does the `tls` block go under `portLevelSettings` for port `80`, and not on port `443` or at the top of `trafficPolicy`?
6. What is the difference between `sni` and `subjectAltNames`?
7. The access log shows `503 URX,UF` and `WRONG_VERSION_NUMBER`. What is missing?
8. Why can a `VirtualService` timeout work for `http://httpbin.org` but not for `https://httpbin.org`?

## Clean up the playground

Remove everything before you leave. First see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-04
```

If `astrona list` also showed the lab, remove it the same way:

```sh
astrona destroy ats-015-lab-040-04-01
```

Then check that everything is gone:

```sh
astrona list
```

```
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *The app speaks plain HTTP to its own sidecar, and the sidecar starts TLS, checks the server's name, and connects to port 443.*
