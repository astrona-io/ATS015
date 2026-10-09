---
estimated_duration: 15m
---

# Close A Path With DENY

A small app has an admin area that no workload inside the cluster should reach. Until it is removed, it must stay closed, even when someone later adds a careless `ALLOW` policy for it.

In this lab you allow the service's normal call, deny the admin path and everything beneath it with a `DENY` policy, and prove that an `ALLOW` for the same path changes nothing.

This lab uses its own small app, not the Starfleet: `notification-service`, `booking-service` and a `tester` client in the namespace `deny-demo`.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-02
```
