---
estimated_duration: 25m
---

# Allow Only One Caller To One TCP Port

Status: **UNTESTED.** This lab was written from the Istio documentation and has not been run on a cluster.

A TCP server must accept connections from one named workload on one port, and a second port must stay closed for everyone. In this lab you write an `ALLOW` policy that matches a caller identity and ports, add a `DENY` policy scoped to one port, and prove the result with real connections.

The lab runs in the namespace `starfleet` with `tcp-echo` (the server), `shuttle` and `relay` (two clients).

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-03
```
