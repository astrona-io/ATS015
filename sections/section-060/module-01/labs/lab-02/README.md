---
estimated_duration: 15m
---

# Allow Callers By Identity With L4 Policy

The `starfleet` namespace runs in ambient mode: no sidecars, only ztunnel on every node. Two backends hold sensitive data, and right now any workload can reach them.

Your job is to allow only `bridge` to reach `cargo`, and only `scout` to reach `navcom`, with identity rules that ztunnel enforces on its own. No waypoint.

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
