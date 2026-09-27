# Case Study: LAB015-030-01 — Require A Valid End-User Token

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The notification service is about to be exposed to a partner integration that
authenticates its users with an identity provider you do not control. All you get
is an issuer name and a URL where its public keys live.

You have been asked to make sure that nothing reaches the service without a
token that provider signed — and to be able to explain, when a partner opens a
ticket, whether a rejection was their token or your rules.

## What good looks like

- A request carrying a valid token is served.
- A request carrying a broken token is rejected, and the rejection is
  distinguishable from a policy refusal.
- A request carrying no token at all is refused, rather than sailing through.
- The service next door is unaffected.

## Hints

1. Two objects, not one. The first is about *how to check a token*; the second is
   about *whether one is required*. Getting only the first is the classic
   mistake, and it looks like it worked.
2. Try it with no token after applying only the first object, and watch what
   happens. That result is the whole reason the second object exists.
3. The `issuer` you configure is compared to a claim inside the token as an exact
   string. Decode the token and look, rather than typing what you remember.
4. `401` and `403` come from different stages of the request path. Knowing which
   is which tells you which object to go and fix.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Use an inline `jwks` instead of `jwksUri` and compare the failure modes.
- Set `audiences` and test a token whose `aud` does not match.
- Enable `outputPayloadToHeader` and read the decoded claims in the upstream request.
