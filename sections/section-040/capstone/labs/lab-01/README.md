---
estimated_duration: 45m
---

# Capstone: Terminate And Pass Through TLS On One Gateway

Astronaut, this is your Section 040 capstone mission. Two services share one arrival gate on port 443, and they want opposite things. For one, the gate opens the sealed signal and routes it by path. For the other, the gate must forward the sealed signal unopened. You also send plain-text visitors to the secure door.

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
