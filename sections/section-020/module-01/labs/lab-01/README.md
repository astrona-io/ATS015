---
estimated_duration: 3m
---

# Lock A Namespace Down With ALLOW Policies

Welcome to a lockdown mission, astronaut. On the planet `authz-demo`, mTLS is `STRICT`, so every caller's ID badge is checked. But no guard stands at any airlock yet, so every call gets through, including a test pod calling the notification service directly.

Your job is to close the whole namespace with `AuthorizationPolicy` objects, then reopen exactly the two calls the app's design needs: one by namespace, one by exact identity.

This mission runs on a small app of its own, not the Starfleet: `booking-service`, `notification-service` and a `tester` client.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-01
```
