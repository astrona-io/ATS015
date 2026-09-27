# Case Study: CAP015-030 — End-User Authentication Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The notification service is being opened to a partner's users. Their identity
provider issues tokens and puts group membership in them; you control none of
that and get only an issuer name and a keys URL.

Two requirements came with it. Nobody gets in without a token from that issuer.
And the admin path is for administrators, which the token itself will tell you.

A colleague's first attempt configured validation and declared it done. Requests
with no token sailed straight through.

## What good looks like

- A broken token and a missing token both fail — and fail differently, so a
  support ticket can be routed without guessing.
- An ordinary user can do ordinary things and nothing more.
- The admin path checks a claim, and a token that simply lacks the claim is
  refused rather than let through.
- A caller with no credentials at all cannot reach the admin rule by any route.

## Hints

1. Three objects' worth of intent, but not three objects. Work out which concerns
   belong to validation and which to authorization.
2. Validation alone protects nothing. Prove that to yourself before adding the
   rest — it is the whole reason the second object exists.
3. A `when` condition is evaluated against whatever attributes a request has. A
   request with none can still reach a rule you thought was guarded.
4. Decode both tokens first. The difference between them is the entire exercise,
   and the claim name is not negotiable.
