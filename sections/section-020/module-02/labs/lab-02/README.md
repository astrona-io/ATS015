---
estimated_duration: 15m
---

# Make The Probe Read-Only

Welcome to a lockdown mission, astronaut. On the planet `starfleet`, the echo probe has an open guest list: every ship on the planet may send it any signal. Mission control now wants the probe to be read-only, for every caller, without anyone touching that guest list.

Your job is to write one `DENY` policy with one negative field, and prove that reads still work while every other method is refused.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-02-02
```
