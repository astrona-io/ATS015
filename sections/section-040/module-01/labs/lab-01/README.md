---
estimated_duration: 3m
---

# Serve HTTPS At The Ingress Gateway

Welcome to your first edge mission, astronaut. In this graded lab you put a TLS certificate where the ingress gateway can read it, serve HTTPS for one host name, and redirect plain HTTP callers to HTTPS. The lab runs a small app of its own (`booking-service` in `tls-demo`), not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-01
```
