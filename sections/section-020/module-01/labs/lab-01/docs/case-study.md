# Case Study: LAB015-020-01 — Lock A Namespace Down With ALLOW Policies

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

mTLS is on, so everything in `authz-demo` is encrypted and every caller's
identity is verifiable. An auditor has just pointed out that this proves who is
calling and permits everything anyway — including a debugging pod calling the
notification service directly, bypassing the booking flow entirely.

You have been asked to close the namespace and reopen only the two calls the
design actually requires.

## What good looks like

- A workload nobody has written a rule for is unreachable, including one deployed
  next week.
- The booking endpoint is reachable by the namespace, but only for the one method
  and path it serves.
- The notification endpoint is reachable by exactly one caller, identified by
  something that survives a rename or a rescheduling.
- Nothing in any Deployment changed.

## Hints

1. There is an idiomatic one-object way to close a whole namespace. It has an
   empty spec, and reading each omitted field tells you why it works.
2. Adding more `ALLOW` policies does not narrow anything. Work out what the
   narrowing step actually is, and when it happens.
3. A rule with only a `from` block permits that caller to do *anything*. If the
   task names a method and a path, both belong in the same rule.
4. Check your own work with all five calls before submitting — in particular the
   two that must be `403` for a *method* reason rather than a caller reason.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Replace `principals` with `namespaces` and describe the security difference.
- Add a `when` condition on a request header and test both values.
- Write the same policy with `notPaths` and reason about which form is safer.
