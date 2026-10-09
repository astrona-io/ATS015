---
estimated_duration: 40m
---

# Capstone: Require A Token And Split Access By Claim

Astronaut, this is your Section 030 capstone mission. You set up the pass checker for one issuer, make a boarding pass required, and let only one crew group through the admin door. Two failures look alike here, `401` and `403`, and you need to know which object sent each one.

This lab fetches Istio's published demo tokens from the internet, so your machine needs outbound internet access. There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-030
```
