---
estimated_duration: 3m
---

# Fix A Broken HTTPS Gateway

In this troubleshooting lab, every HTTPS request to `bridge` in the namespace `starfleet` fails in the TLS handshake, and Kubernetes reported no error. Somewhere between the TLS Secret and the `Gateway`, two things are wrong.

Your job is to find both faults with curl's exit code, `istioctl proxy-config secret` and `istioctl analyze`, fix them, and prove that `https://starfleet.example.com/productpage` answers `200` with the right certificate.

## Launching the Lab

Run this command to start the cluster with the faults already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-01-02
```
