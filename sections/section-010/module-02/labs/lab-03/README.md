---
estimated_duration: 3m
---

# Fix The Broken Handshake

Welcome to a repair mission, astronaut. On the planet `starfleet`, every ship requires the secret handshake (mTLS). Since a teammate added docking instructions for the probe, the shuttle gets `503` from it. Both ships are in the mesh, and both are healthy.

Your job is to find out which side of the handshake is wrong, fix it on that side, and prove that the shuttle's signals reach the probe with the shuttle's identity again.

## Launching the Lab

Run this command to start the cluster with the fault already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-03
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-03
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-02-03
```
