# Case Study: CAP015-050 — Edge Authorization Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Two requests arrived on the same day.

Abuse wants a network range cut off entirely — it has been hammering the booking
API and none of the traffic is legitimate.

Meanwhile the operations team wants the admin surface reachable only from the
office network. Not blocked outright; restricted.

The gateway is shared with other services, so whatever you write must not close
anything you were not asked to close.

## What good looks like

- The abusive range gets nothing, on any path.
- The admin path is reachable from the office range and from nowhere else.
- Ordinary traffic to ordinary paths is unaffected, including for hostnames you
  were never asked about.
- The rules read the client's real address from a position an attacker cannot
  control.

## Hints

1. One of these is a subtraction and the other is a restriction on one subtree.
   Think about which action expresses each, and what an unqualified allow-list
   would do to a shared gateway.
2. "Deny unless in this range" is one rule, not two. There is a field family for
   inverting a condition — and under a deny action it reads backwards unless you
   say the whole sentence starting with the action.
3. The path field needs to cover more than the exact URL you will test.
4. `404` is a pass on the admin path. `403` is a block.
