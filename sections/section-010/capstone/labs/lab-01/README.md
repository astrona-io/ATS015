---
estimated_duration: 45m
---

# Capstone: Turn On Mesh-Wide mTLS Without Stranding A Caller

This is the Section 010 capstone lab. It joins workload identity, mutual TLS (mTLS) and identity-based authorization into one task. You require mTLS for the whole mesh, first bring one client without a sidecar into the mesh, and let only one service account call the notification service.

The order matters. If you require mTLS too early, the client without a sidecar can no longer connect. There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-010
```
