# Case Study: LAB015-010-01 — Prove A Workload Identity And Authorize On It

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Your team runs a booking system. `booking-service` calls `notification-service`
when a booking is confirmed — that is the only call `notification-service` is
supposed to receive.

A review has just pointed out that it receives rather more than that: anything in
the namespace can call it, and one of those callers is a debugging pod somebody
left running. Nobody wants to rely on that pod's name or labels staying the same,
and its IP changes every restart.

You have been asked to make the restriction hold on something that cannot drift.

## What good looks like

- Traffic into `notification-service` is refused unless the caller can prove a
  specific mesh identity.
- `booking-service` keeps working, with no change to its Deployment.
- The debugging pod is refused, and would still be refused if someone renamed it,
  relabelled it or moved it to another node.
- The identity in your policy came from the certificate the workload presents,
  not from something you inferred.

## Hints

1. Identity-based rules have a precondition. A caller that never presents a
   certificate has no identity to match — which of the two objects fixes that,
   and does it need to come first?
2. `istioctl proxy-config secret deploy/<name> -n <ns> -o json` gives you the
   whole secret. The identity is a URI in the certificate's SAN, so you will
   need to decode the certificate to read it.
3. The SAN and the policy field do not use the same spelling of the identity.
   Compare them character by character before you apply anything.
4. Check your own work before submitting: run the call from `booking-service`
   and the same call from `tester`, and make sure the two results differ for the
   reason you intended — `403`, not a connection error.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Give two Deployments the same service account and show that policy cannot tell them apart.
- Set `trustDomainAliases` and describe when it is needed during a migration.
- Compare `istioctl proxy-config secret` before and after a certificate rotation.
