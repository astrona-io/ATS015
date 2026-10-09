---
estimated_duration: 15m
---

# Route An Encrypted Stream By SNI

In this build lab, a backend ends TLS (Transport Layer Security) itself with its own certificate, and nothing in the middle may decrypt its traffic. You put it behind the shared ingress gateway in passthrough mode, route it on the SNI (Server Name Indication) name, the host name the client sends in clear text, and prove that the certificate the client gets is the backend's own.

This lab uses its own small app (`tls-backend` in `passthrough-demo`), not the Starfleet.

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
