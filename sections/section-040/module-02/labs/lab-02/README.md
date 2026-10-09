---
estimated_duration: 20m
---

# Fix The Gate's Trusted Badge Office

Welcome to a repair mission, astronaut. On the planet `starfleet`, the spaceport arrival gate checks every visitor's badge (client certificate). But the fleet's trusted partner is turned away, and a stranger with a badge from an unknown office walks straight in.

Your job is to find out which badge office the gate trusts, using the gateway's own proxy and the secret it reads, fix it, and prove that only the partner gets in.

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
