---
estimated_duration: 15m
---

# Route An Encrypted Stream By SNI

Welcome to a build mission, astronaut. A backend ship ends TLS itself with its own certificate, and nothing in the middle may open its signals. You put it behind the shared arrival gate in passthrough mode, route it on the address on the envelope (SNI), and prove that the certificate the visitor gets is the backend's own.

This mission uses its own small app (`tls-backend` in `passthrough-demo`), not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-03
```
