---
estimated_duration: 20m
---

# Prove A Workload Identity And Authorize On It

In the namespace `identity-demo`, any workload can call `notification-service`, including a debugging pod somebody left running. Only `booking-service` should be allowed.

Your job is to read the identity `booking-service` really has from its live certificate, require STRICT mutual TLS (mTLS) for the whole namespace, and write an `AuthorizationPolicy` that allows exactly that identity. This lab runs its own small app, not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-01
```
