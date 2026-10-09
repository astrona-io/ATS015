---
estimated_duration: 15m
---

# Allow Only Known Ships At L4

Welcome to a lockdown mission, astronaut. The planet `starfleet` runs in ambient mode: no sidecars, only ztunnel on every node. Two ships carry sensitive data, and right now any ship can signal them.

Your job is to lock the supply ship `cargo` to the flagship, and the navigation computer `navcom` to the scouts, with identity rules that ztunnel enforces on its own. No waypoint.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-060/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-060-01-02
```
