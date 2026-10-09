---
estimated_duration: 3m
---

# Block A Client Range At The Gateway

Welcome to a mission at the arrival gate, astronaut. A range of addresses keeps attacking the booking service behind `booking.ica.local`, and a load balancer hides the real clients from the connection.

Your job is to refuse `192.168.0.0/16` at the ingress gateway, by the client's real address, without closing the gate for anyone else. This mission runs its own small app (`booking-service` in `gwauthz-demo`), not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-050-01
```
