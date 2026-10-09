---
estimated_duration: 15m
---

# Make The Probe Read-Only

In the namespace `starfleet`, the `probe` echo service has an open `ALLOW` policy: every workload in the namespace may send it any request. The probe must now become read-only, for every caller, without anyone touching that `ALLOW` policy.

In this lab you write one `DENY` policy with one negative field, and prove that reads still work while every other method is refused.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-02-02
```
