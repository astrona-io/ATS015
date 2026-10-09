---
estimated_duration: 3m
---

# Read A JWT From A Query Parameter

This is a build lab. In the namespace `starfleet`, an old ground station can only send its token in the URL, as `?token=...`. The probe must read the token from there and nowhere else, and refuse every request without a valid token.

Your job is to write a `RequestAuthentication` with `fromParams`, require the token with a `DENY` policy that uses `notRequestPrincipals`, and prove which requests get `200`, `401` and `403`.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-030-01-02
```
