---
estimated_duration: 45m
---

# Capstone: Terminate And Pass Through TLS On One Gateway

This is the Section 040 capstone lab. Two services share one ingress gateway on port 443, and they need opposite things. For one, the gateway terminates TLS and routes the request by path. For the other, the gateway must pass the encrypted connection through without decrypting it. You also redirect plain HTTP requests to HTTPS.

There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-040
```
