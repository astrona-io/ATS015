---
estimated_duration: 20m
---

# Migrate A Namespace To STRICT mTLS

Welcome to a migration mission, astronaut. The planet `migrate-demo` has run in the mesh for months in the default `PERMISSIVE` mode. One caller, `outside-client` on the planet `outside`, still sends plain signals to it.

Your job is to bring that caller into the mesh and then switch `migrate-demo` to `STRICT` mTLS, in an order that never breaks it.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-010-03
```
