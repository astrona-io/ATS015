---
estimated_duration: 3m
---

# Fix A DestinationRule That Breaks mTLS

This is a troubleshooting lab. In the namespace `starfleet`, every workload requires mTLS (mutual TLS, where both sides present a certificate). Since a teammate added a `DestinationRule` for the probe, the shuttle gets `503` from it. Both workloads are in the mesh, and both are healthy.

Your job is to find out which side of the connection is misconfigured, fix it on that side, and prove that the shuttle's requests reach the probe with the shuttle's identity again.

## Launching the Lab

Run this command to start the cluster with the fault already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-03
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-03
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-02-03
```
