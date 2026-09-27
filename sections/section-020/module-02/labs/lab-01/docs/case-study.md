# Case Study: LAB015-020-02 — Close A Path With DENY

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The notification service has an admin surface that was never meant to be
reachable from inside the cluster. It is being removed next quarter; until then
it has to be unreachable, and it has to *stay* unreachable when somebody who has
never heard of this conversation adds a generous `ALLOW` rule six months from
now.

To prove the protection actually holds, you are going to write that careless
`ALLOW` yourself and leave it in place.

## What good looks like

- The service's normal call still works.
- The admin path is refused — and so is everything under it, not just the exact
  URL you tested.
- A policy explicitly permitting the admin path exists and changes nothing.
- You can say, without running anything, why it changes nothing.

## Hints

1. Two of the three objects have the same `action`. One does not.
2. Path matching is more literal than it looks. Test a path one level deeper
   than the one you wrote.
3. One of the three groups of policies is evaluated before the others and ends
   the decision on a match. Which one, and what does "ends" mean for everything
   after it?
4. `404` is not `403`. If you see `404`, the request reached the application —
   the mesh let it through.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Express the same intent using only ALLOW policies and compare which version is easier to review.
- Add a `when` condition on `request.auth.claims` and combine it with DENY.
- Create a mesh-wide DENY in the root namespace and check its effect on another namespace.
