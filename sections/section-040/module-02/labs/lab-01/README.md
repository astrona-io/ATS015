---
estimated_duration: 20m
---

# Require Client Certificates At The Edge

Welcome to a build mission, astronaut. A booking service is being opened to a few partner systems, and to nobody else. These are machines calling machines, and the list of callers is short and known.

Your job is to build a secret with three keys and a `MUTUAL` gateway, so that only clients with a certificate from the given CA reach the service, and to prove that the gateway really checks. This mission uses its own small app (`booking-service` in `mtlsedge-demo`) and the gateway of an `istioctl` demo install (`istio-ingressgateway` in `istio-system`).

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-02
```
