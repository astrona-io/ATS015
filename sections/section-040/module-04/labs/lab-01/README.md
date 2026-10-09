---
estimated_duration: 20m
---

# Seal The Signal To An Outside Planet

Welcome to your mission, astronaut. The shuttle on the planet `starfleet` sends plain `http://` signals to `httpbin.org`, a planet in another solar system. Today they cross the internet unsealed. Your job is to make the shuttle's sidecar, its communications officer, seal every one of them with TLS on the way out, and check the planet's ID card while it does.

httpbin.org reports the scheme it was reached on, so there is no guessing whether the seal was added. This lab needs **outbound internet access**.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-04/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-04/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-04-01
```
