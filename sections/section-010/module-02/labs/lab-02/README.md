---
estimated_duration: 3m
---

# Open One Port For The Drifter

Welcome to a build mission, astronaut. The whole mesh requires the secret handshake (mTLS). The drifter, an old ship on the planet `outpost` with no communications officer, can no longer reach anyone. One ship, the probe, must accept it again, but only on the one radio channel the drifter uses.

Your job is to open exactly one port of the probe with `portLevelMtls`, and prove that every other ship still refuses the drifter.

## Launching the Lab

Run this command to start the cluster with the mesh already strict:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-02-02
```
