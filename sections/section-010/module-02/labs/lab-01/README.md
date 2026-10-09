---
estimated_duration: 3m
---

# Enforce mTLS At Three Scopes

Welcome to a build mission, astronaut. Security wants the secret handshake (mTLS) required across the whole mesh. One team on the planet `mtls-demo` still has a caller outside the mesh, so their planet gets an exception. Their notification service is the sensitive one, and it does not get the exception.

Your job is to write three `PeerAuthentication` policies at three scopes, so that the narrowest one wins for each workload, and to prove it with real signals. This mission uses its own small app, not the Starfleet.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-02
```
