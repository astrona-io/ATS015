---
estimated_duration: 20m
---

# Enforce L4 And L7 Policy In Ambient Mode

Welcome to an ambient mission, astronaut. Namespace `ambient-authz` runs in ambient mode: no sidecars, only ztunnel. Someone ported an old method rule across, saw it listed by `kubectl get`, and closed the ticket. It was never enforced.

Your job is to do it properly: add a waypoint, send the traffic through it, and write one policy that allows one identity and one method, so you can prove which component enforces the rule.

This mission uses its own small app (`notification-service` with two client pods), not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-060/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-060-01
```
