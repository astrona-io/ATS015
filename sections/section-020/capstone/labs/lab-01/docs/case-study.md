# Case Study: CAP015-020 — Authorization Policy Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

You are writing the access model for a namespace that currently has none. Two
calls are legitimate; everything else is not. And there is one surface — an admin
path on the notification service — that must be unreachable regardless of what
anyone adds to the access model later.

The last part is the interesting one. Your colleague's argument is that a future
`ALLOW` could always reopen it, so a comment in the repo is the best you can do.
You are going to demonstrate otherwise.

## What good looks like

- A service deployed into this namespace tomorrow, with no rules of its own, is
  unreachable.
- The two legitimate calls work, and only for the method and path they need.
- One of them is restricted by identity, not by namespace.
- The admin surface is refused, including everything beneath it, while a policy
  explicitly permitting it sits right there doing nothing.

## Hints

1. Start with the object that closes the namespace. Everything else is a hole you
   deliberately open in it.
2. Two workloads, two different notions of "who". Only one of them can be
   expressed with a namespace.
3. More `ALLOW` policies never restrict. If part 3 is to survive a careless
   future rule, it cannot be an `ALLOW`.
4. Test one level deeper than the path you wrote. That is where this kind of rule
   usually leaks.
