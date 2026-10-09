---
estimated_duration: 40m
---

# Capstone: Deny By Default And Allow Two Calls

This is the Section 020 capstone lab. You deny all requests in a whole namespace, then allow exactly two calls: one from any workload in the namespace, and one from a single service account. Last, you block an admin path with a `DENY` policy, so that no later `ALLOW` policy can ever open it again.

There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-020
```
