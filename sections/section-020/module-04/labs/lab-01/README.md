---
estimated_duration: 25m
---

# Gate One Path With An External Authorizer

Status: **UNTESTED.** This lab was written from the Istio documentation and has not been run on a cluster.

A workload has one path that must be checked by an external authorization service before the request reaches it. In this lab you register the sample authorizer as an extension provider in the mesh configuration, write a `CUSTOM` policy for one path, and prove the result with real requests.

The lab runs in the namespace `starfleet` with `probe` (the protected workload), `ext-authz` (the authorizer) and `shuttle` (the client).

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-04/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-04/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-04
```
