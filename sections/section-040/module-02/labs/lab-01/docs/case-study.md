# Case Study: LAB015-040-02 — Require Client Certificates At The Edge

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The booking API is being opened to three partner systems — and to nobody else.
There are no browsers involved and no end users to log in; these are machines
calling machines, and the list of legitimate callers is short and known.

Your organisation already runs a CA and has issued each partner a certificate.
You have been asked to make the gateway refuse anyone who cannot present one.

## What good looks like

- A caller holding a certificate from your CA is served.
- A caller with no certificate never gets to send a request at all.
- So does a caller with a certificate from some other CA.
- You can demonstrate that the check is on, without relying on a request having
  failed.

## Hints

1. The credential for this mode carries one more thing than it did for ordinary
   HTTPS, and the tool you used last time cannot add it.
2. Key names inside the secret are fixed. A secret with plausible-looking names
   applies cleanly and delivers nothing.
3. This configuration fails **open**: get it subtly wrong and the gateway serves
   TLS happily and checks nobody. So "my request worked" proves nothing on its
   own — find the field on the listener that says whether verification is armed.
4. A rejected client does not get an HTTP status. Do not go looking for a `403`.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Revoke trust by replacing the CA in the secret and confirm the previously valid client now fails.
- Combine edge MUTUAL TLS with an `AuthorizationPolicy` that matches on the client certificate subject.
- Use a separate `<credentialName>-cacert` secret instead of the combined form.
