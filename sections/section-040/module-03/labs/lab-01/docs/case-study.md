# Case Study: LAB015-040-03 — Route An Encrypted Stream By SNI

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

A backend team runs a service that pins its own certificate and authenticates
some callers by their client certificate. They have been clear: nothing in the
middle may terminate their TLS, and the certificate their clients see must be
theirs.

You still need to put it behind the shared ingress gateway, alongside everything
else.

## What good looks like

- Traffic for the backend's hostname reaches it through the gateway.
- The certificate a client receives is the backend's own.
- No credential was created for the gateway, because it has nothing to present.
- You can say which gateway capabilities this hostname has just given up.

## Hints

1. A proxy with no key can read exactly one useful thing out of a TLS
   connection, and it is in the very first message. Everything about the
   configuration follows from that.
2. The `Gateway` port block is not the one you used for HTTPS. One field says
   "terminate this and parse HTTP inside" — you do not want that.
3. A `VirtualService` has more than one routing section. The one you have been
   using needs a method and a path, and neither exists here.
4. When it fails, it fails as a connection error rather than a `404` — producing
   a `404` would require reading the request.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Serve two backends with different SNI hosts on the same gateway port.
- Compare the gateway access log for a passthrough and a terminated request.
- Switch the same backend to terminated TLS and rewrite the VirtualService accordingly.
