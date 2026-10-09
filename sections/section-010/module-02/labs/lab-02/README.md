---
estimated_duration: 3m
---

# Open One Port With portLevelMtls

This is a build lab. The whole mesh requires mTLS (mutual TLS, where both sides present a certificate). The drifter, a client pod in the namespace `outpost` with no sidecar proxy, can no longer reach any workload. One workload, the probe, must accept it again, but only on the one port the drifter uses.

Your job is to open exactly one port of the probe with `portLevelMtls`, and prove that every other workload still refuses the drifter.

## Launching the Lab

Run this command to start the cluster with the mesh already strict:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-02-02
```
