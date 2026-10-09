---
estimated_duration: 3m
---

# Repair The Fleet's Guest Lists

Welcome to a repair mission, astronaut. On the planet `starfleet`, every ship has its own least-privilege guest list, and the planet is closed by default. That part works: nobody can take a shortcut. But the bridge page is broken too, and the fleet needs it back.

Your job is to find the faults with the flight logs, the proxy's own orders and `istioctl analyze`, fix them, and prove that the page works again while every shortcut stays closed.

## Launching the Lab

Run this command to start the cluster with the faults already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-020-01-02
```
