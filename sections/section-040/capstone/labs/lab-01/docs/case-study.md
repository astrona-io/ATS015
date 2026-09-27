# Case Study: CAP015-040 — Edge TLS Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Two services are going behind the same shared ingress gateway on the same port,
and they want opposite things.

The booking API is a normal public HTTPS service: you hold the certificate, and
the gateway should see requests so it can route by path.

The other team refuses to hand over their key. Their service pins its own
certificate and authenticates some callers by client certificate; nothing in the
middle may decrypt it.

Both have to work, on port 443, at the same time.

## What good looks like

- Each hostname is answered with the certificate it is supposed to present.
- One hostname supports path routing; the other reaches its backend untouched.
- Plaintext callers to the public hostname are redirected rather than served.
- You could explain which gateway features the second hostname has given up.

## Hints

1. The two requirements differ in one field in the port block and one field in
   the `tls` block — and in whether a credential is named at all.
2. Something has to pick between two listeners on the same port before any HTTP
   exists. Work out what that is, and make sure your tests actually send it.
3. The two hostnames do not route the same way. A `VirtualService` has more than
   one routing section for a reason.
4. Confirm success by the certificate you were served, not by the status code —
   `200` looks identical in both modes.
