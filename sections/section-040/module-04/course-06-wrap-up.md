# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about letting the communications officer (the sidecar proxy) seal signals to a planet in another solar system, so the app can speak plain HTTP and the mesh can still read every request.

**From [Who Seals The Signal](./course-01-who-seals-the-signal.md):**

- When the app seals its own signal, the sidecar sees only the destination address, the SNI name, byte counts and whether the connection worked. The flight log shows `"- - -"` and status `0`.
- The seal can be added by the app, by its own sidecar (TLS origination) or by an egress gateway.
- The app must call `http://` for origination to work.
- `tls.mode` in a `DestinationRule` describes what the client side sends: `DISABLE`, `SIMPLE`, `MUTUAL` or `ISTIO_MUTUAL`.

**From [Chart The Planet And Seal The Signal](./course-02-chart-the-planet-and-seal-the-signal.md):**

- The `ServiceEntry` charts `httpbin.org` with port `80` (`HTTP`, `targetPort: 443`) and port `443` (`HTTPS`). On its own, it sends plain HTTP to port `443`, and the server answers `400`.
- The `DestinationRule` puts `tls.mode: SIMPLE` and `sni` under `portLevelSettings` for port `80`. Then httpbin.org reports `"url": "https://httpbin.org/get"`.
- The app's own `https://` calls keep working, because port `443` is not touched.
- `istioctl proxy-config cluster ... --port 80 -o json` shows `envoy.transport_sockets.tls` and the `sni` name on the sealed port.

**From [Check The Planet's ID Card](./course-03-check-the-planets-id-card.md):**

- `subjectAltNames` lists the names the server's certificate must carry. A wrong name fails with `503 URX,UF` and `CERTIFICATE_VERIFY_FAILED`.
- `sni` is only the name the sidecar asks for. A wrong `sni` was not caught at httpbin.org.
- Without `caCertificates`, the sidecar trusts the usual public certificate authorities.

**From [A Seal On The Wrong Channel](./course-04-a-seal-on-the-wrong-channel.md):**

- Without `targetPort`, the sidecar sends a TLS handshake to port `80`, and the call fails with `503 URX,UF` and `WRONG_VERSION_NUMBER`.
- `400` means the seal is missing, `WRONG_VERSION_NUMBER` means the seal went to the wrong port, and `CERTIFICATE_VERIFY_FAILED` means the server's card does not match.

**From [Use What You Won](./course-05-use-what-you-won.md):**

- A `VirtualService` with `timeout: 2s` turns a slow outside HTTPS call into `504 UT`. That only works because the sidecar reads the plain signal.
- `MUTUAL` adds a client certificate, from a secret in the calling workload's namespace (`credentialName`) or from files in the sidecar container.

## Your missions

| Mission | What you proved | After part |
| --- | --- | --- |
| [Seal The Signal To An Outside Planet Lab](./labs/lab-01/question.md) | Make the shuttle's sidecar seal plain `http://` signals to `httpbin.org` and check the server's name | Check The Planet's ID Card |

## Check yourself

Answer these without looking back. If one is hard, reread the part it comes from.

1. An app calls `https://api.example.com`. Which four things can its sidecar still see?
2. What does the `"url"` field in httpbin.org's answer tell you, and why is it good proof?
3. Which two settings make TLS origination work, and which one decides *where* and which one *how* the sidecar connects?
4. You applied the `ServiceEntry` with `targetPort: 443` but no `DestinationRule`. What does the server answer, and why?
5. Why does the `tls` block go under `portLevelSettings` for port `80`, and not on port `443` or at the top of `trafficPolicy`?
6. What is the difference between `sni` and `subjectAltNames`?
7. The flight log shows `503 URX,UF` and `WRONG_VERSION_NUMBER`. What is missing?
8. Why can a `VirtualService` timeout work for `http://httpbin.org` but not for `https://httpbin.org`?

## Clean up the playground

Land everything before you leave. First see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-040-04
```

If `astrona list` also showed the mission, remove it the same way:

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

> *The app speaks plain HTTP to its own sidecar, and the sidecar seals the signal, checks the planet's name, and leaves on port 443.*
