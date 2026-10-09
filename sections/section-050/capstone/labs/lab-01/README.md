---
estimated_duration: 30m
---

# Capstone: Block Client IP Ranges At The Ingress Gateway

This is the Section 050 capstone lab. At the ingress gateway, you block one range of client IP addresses on every path, and you restrict the admin path so that only the office range can reach it. The gateway is shared, so nothing else may be blocked.

There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-050
```
