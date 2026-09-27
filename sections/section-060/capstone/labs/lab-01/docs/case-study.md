# Case Study: CAP015-060 — Ambient Authorization Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

The requirement is one sentence: *only the tester workload may call the
notification service, and only to post a notification.*

In sidecar mode that was one policy. This namespace runs in ambient mode, and the
same sentence now has to be split across two components — one that can see who
is connecting and one that can see what they are asking for. Half of it will be
enforced whether or not you do anything special; the other half will silently do
nothing until you deploy something.

Your reviewer's question will be: *which component is enforcing which half, and
how do you know?*

## What good looks like

- The wrong identity cannot open a connection at all — it never reaches an HTTP
  layer.
- The right identity can post a notification, and nothing else.
- Every policy you applied is actually held by some component; none is inert.
- You can show which one holds which.

## Hints

1. Sort the requirement into fields decidable from a connection and fields that
   need the request. That split *is* the design.
2. The two halves attach differently. One points at pods; the other points at
   the thing in front of a service.
3. Creating the extra component and sending traffic through it are two steps. The
   first alone leaves everything looking healthy and changes nothing.
4. The tooling differs too — `proxy-config` against an application pod has no
   counterpart here.
