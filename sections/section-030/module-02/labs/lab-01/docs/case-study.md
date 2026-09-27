# Case Study: LAB015-030-02 — Authorize On A JWT Claim

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Every logged-in user now carries a valid token, and the notification service
accepts all of them. That was the right first step and it is not enough: the
service has an admin path, and "logged in" is not the same as "an administrator".

The identity provider already puts group membership in the token. You have been
asked to use it — without trusting anything the caller can simply set.

## What good looks like

- An ordinary user can do ordinary things.
- The admin path is reachable only by someone whose token says they belong to the
  admin group.
- A caller with no token is refused everywhere, and cannot slip past the admin
  rule by simply not presenting credentials.
- The rule names the claim the issuer actually emits, not the one its console
  displays.

## Hints

1. Decode both tokens before writing anything. The difference between them is
   the entire point of the exercise.
2. A `when` condition is evaluated against whatever attributes a request has —
   which means a request with no attributes at all can reach a rule you thought
   was guarded. Pair the condition with something that requires a token.
3. `groups` is a list in the token, and the matching syntax for a list is not
   special. Try the obvious thing.
4. `404` is a pass, `403` is a block. Test against a path whose normal behaviour
   you already know.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Match on `request.auth.claims[scope]` and compare with a `groups` match.
- Use `notValues` to exclude one group and reason about the security implication.
- Combine a claim condition with a source principal so both the workload and the user must match.
