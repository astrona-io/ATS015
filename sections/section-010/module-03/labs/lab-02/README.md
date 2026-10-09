---
estimated_duration: 3m
---

# Keep One Port Open For The Drifter

Welcome to a repair mission, astronaut. The planet `starfleet` accepts only mTLS signals. The `drifter` on the planet `outpost` can never do the handshake, so someone wrote a port exception for the `probe`. It was accepted without an error, and it does nothing: the drifter still gets a connection reset.

Your job is to find out why, fix the exception, and prove that the drifter reaches the probe while every other ship stays `STRICT`.

## Launching the Lab

Run this command to start the cluster with the fault already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-03/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-03-02
```
