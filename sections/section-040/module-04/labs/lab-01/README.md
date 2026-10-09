---
estimated_duration: 20m
---

# Originate TLS To An External Service

The `shuttle` pod in the `starfleet` namespace sends plain `http://` requests to `httpbin.org`, a public service outside the cluster. Today they cross the internet unencrypted. Your job is to make the `shuttle` pod's sidecar proxy (Envoy) originate TLS for every one of them on the way out, and check the server's certificate name while it does.

httpbin.org reports the scheme it was reached on, so there is no guessing whether TLS was used. This lab needs **outbound internet access**.

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
