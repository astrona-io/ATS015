---
estimated_duration: 20m
---

# Prove A Workload Identity And Authorize On It

Welcome to your first security mission, astronaut. On the planet `identity-demo`, anything can call `notification-service`, including a debugging pod somebody left running. Only `booking-service` should get through.

Your job is to read the ID badge `booking-service` really carries from its live certificate, require the secret handshake (mTLS) for the whole planet, and write a guest list that lets in exactly that badge. This mission runs its own small app, not the Starfleet.

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
