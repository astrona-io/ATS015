# Case Study: LAB015-060-01 — Enforce L4 And L7 Policy In Ambient Mode

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Your platform team has moved this namespace to ambient mode. The sidecars are
gone, nothing had to be restarted, and everyone is pleased.

Then someone ports the old authorization policy across, applies it, sees it
listed by `kubectl get`, and closes the ticket. A week later an audit finds the
method restriction was never enforced at any point.

You have been asked to do it properly, and to be able to show which component is
enforcing which half.

## What good looks like

- The wrong identity cannot open a connection at all.
- The right identity can do the one thing it is supposed to do, and not the
  others.
- Nothing in your configuration is "applied but inert".
- You can point at the component holding each rule.

## Hints

1. Some fields are decidable from a connection and some need the request. Sort
   your requirements into those two buckets before writing anything.
2. One bucket needs an extra component. That component existing is not the same
   as traffic going through it — there are two steps, and skipping the second
   leaves everything looking healthy.
3. The two buckets attach differently. One points at pods; the other points at
   the thing in front of a service.
4. Read the failures. A connection error and a `403` are telling you which
   component made the decision.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Attach the L7 policy with `targetRefs` to the Service instead of the waypoint Gateway.
- Add a JWT rule and confirm it requires the waypoint as well.
- Remove the waypoint and watch the L7 rule stop being enforced while the L4 rule survives.
