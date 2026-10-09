---
estimated_duration: 3m
---

# Repair Broken AuthorizationPolicies

In the namespace `starfleet`, every workload has its own least-privilege `AuthorizationPolicy`, and the namespace is closed by default. That part works: nobody can take a shortcut. But the `bridge` page is broken too, and the crew needs it back.

Your job is to find the faults with the access logs, the proxy configuration and `istioctl analyze`, fix them, and prove that the page works again while every shortcut stays closed.

## Launching the Lab

Run this command to start the cluster with the faults already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-01-02
```
