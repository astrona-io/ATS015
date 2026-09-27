# Case Study: LAB015-040-01 — Serve HTTPS At The Ingress Gateway

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The booking API is going public. Somebody has handed you a certificate and a key
for `booking.ica.local` and asked you to put the service behind HTTPS, with
plaintext callers redirected rather than served.

Everything inside the mesh already uses mutual TLS, which turns out to be
irrelevant here: the client is a browser, and it will check the certificate
against a name it already trusts.

## What good looks like

- An HTTPS request for `booking.ica.local` reaches the booking service.
- The certificate the client is offered is the one you were handed, not a mesh
  certificate and not a default.
- A plaintext caller is told to come back over TLS.
- The certificate can be replaced later without restarting the gateway.

## Hints

1. `credentialName` is a bare name, and it is not resolved where the `Gateway`
   object lives. Getting this wrong applies cleanly and produces a listener that
   never comes up — `istioctl proxy-config secret` on the gateway is how you
   find out.
2. Two properties of the port block matter, and one of them looks like a label.
3. Testing needs the right SNI, not just the right `Host` header. `curl
   --resolve` sets both; a bare `-H "Host: ..."` over HTTPS does not.
4. The redirect listener is on the plaintext port and still has a `tls` block.
   Only one field belongs in it.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Rotate the certificate by replacing the secret and confirm the gateway picks it up without a restart.
- Serve two hostnames with two certificates on the same gateway.
- Add `minProtocolVersion: TLSV1_3` and test with an older client.
