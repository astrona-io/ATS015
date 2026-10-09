---
estimated_duration: 3m
---

# Fix The Claim Rule

Welcome to a repair mission, astronaut. On the planet `starfleet`, the echo probe has an access policy that looks right and is not. Administrators are refused at the admin path, and the public path asks everyone for a token.

Your job is to find both faults with a decoded token and the probe's proxy configuration, fix the policy, and prove each path answers the right callers.

## Launching the Lab

Run this command to start the cluster with the faults already in place. It needs outbound internet access for the sample tokens and keys:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-030-02-02
```
