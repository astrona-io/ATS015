---
estimated_duration: 40m
---

# Plug In A CA And Shorten One Certificate Lifetime

Status: **UNTESTED.** This lab was written from the Istio documentation and has not been run on a cluster.

The security team requires that workload certificates chain to a CA you control, and that one sensitive workload use a short-lived certificate. In this lab you create a root and an intermediate CA with `openssl`, give them to `istiod` in the `cacerts` Secret, restart so every workload gets a new certificate, and shorten the lifetime of one workload.

The lab runs in the namespace `ca-demo` with `shuttle` (a client), `probe-long` and `probe-short` (two echo servers). You need `openssl` on your machine.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-04/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-04/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-04
```
