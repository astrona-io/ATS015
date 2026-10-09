---
estimated_duration: 3m
---

# Authorize On A JWT Claim

In the namespace `jwtclaims-demo`, every logged-in user can reach the notification service, and that includes its `/admin` path. "Logged in" is not the same as "administrator".

Your job is to keep the ordinary path open to any valid token, open the `/admin` path only to tokens whose `groups` claim contains `group1`, and refuse every request that carries no token.

This lab uses its own small app (`notification-service` and a `tester` client), not the Starfleet.

## Launching the Lab

Run this command to start the cluster. It needs outbound internet access for the sample tokens and keys:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-030-02
```
