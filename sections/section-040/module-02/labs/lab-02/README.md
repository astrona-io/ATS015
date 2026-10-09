---
estimated_duration: 20m
---

# Fix The Trusted CA In A MUTUAL Gateway

This is a troubleshooting lab. The ingress gateway in front of the `starfleet` namespace checks every client certificate. But the trusted partner is refused, and an unknown client with a certificate from another certificate authority (CA) gets straight in.

Your job is to find out which CA the gateway trusts, using the gateway's own proxy and the secret it reads, fix it, and prove that only the partner gets in.

## Launching the Lab

Run this command to start the cluster with the fault already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-02-02
```
