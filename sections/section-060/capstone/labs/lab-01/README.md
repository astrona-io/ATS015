---
estimated_duration: 40m
---

# Capstone: Enforce Request Rules Through A Waypoint

Astronaut, this is your Section 060 capstone mission. The planet runs in ambient mode: ships fly without their own communications officer, and shared relay towers carry their signals. Relay towers cannot read a signal's contents, so a rule about methods and paths needs a checkpoint station that can. You build that station, send the traffic through it, and attach the rule to it.

There is no walkthrough until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-060/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-capstone-060
```
