---
estimated_duration: 3m
---

# Require A Valid End-User Token

Welcome to a build mission, astronaut. On the planet `jwt-demo`, the notification service answers anyone. It must only answer requests that carry a valid token from Istio's demo issuer, while the booking service next door stays open.

Your job is to check tokens with a `RequestAuthentication`, make one required with an `AuthorizationPolicy`, and prove that a missing token gets `403`, a bad token `401` and the demo token `200`.

This mission uses its own small app (`notification-service`, `booking-service` and a `tester` client), not the Starfleet. The cluster needs outbound internet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-030-01
```
