---
estimated_duration: 40m
---

# Capstone: Enforce Request Rules Through A Waypoint

This is the Section 060 capstone lab. The namespace runs in ambient mode: pods have no sidecar proxy, and a shared per-node proxy called ztunnel carries their traffic. ztunnel cannot read HTTP, so a rule about methods and paths needs a waypoint proxy that can. You deploy the waypoint, send the traffic through it, and attach the rule to it.

There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-060/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-060
```
