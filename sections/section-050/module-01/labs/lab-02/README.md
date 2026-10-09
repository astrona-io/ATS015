---
estimated_duration: 3m
---

# Open One Path To One Network

In this lab you work on the ingress gateway. In the namespace `starfleet`, anyone can reach the `bridge` API through the gateway. Only the office network should.

Your job is to close `/api/v1/products` to everyone outside `203.0.113.0/24`, by the client's real address, while `/productpage` stays open for all.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-050-01-02
```
