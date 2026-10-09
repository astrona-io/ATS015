---
estimated_duration: 45m
---

# Capstone: Turn On Mesh-Wide mTLS Without Stranding A Caller

Astronaut, this is your Section 010 capstone mission. It joins ID badges, handshakes and badge checks into one job. You make the secret handshake (mutual TLS) required for the whole fleet, bring one old ship without a badge into the mesh first, and let only one named ship reach the notification service.

The order matters. Turn on the handshake too early, and the old ship loses contact. There is no walkthrough until you have tried it. Work from the task.

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
