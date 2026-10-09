---
estimated_duration: 20m
---

# Fix A Passthrough Gateway That Routes Nothing

In this troubleshooting lab, the ingress gateway should pass the encrypted traffic of `tls-backend` through without decrypting it, and every object applied without an error. Still, every client gets no response at all. There is more than one fault.

Your job is to find each fault with the gateway's listener and route table, fix it, and prove that a client reaches `tls-backend` and gets the certificate that `tls-backend` made itself.

## Launching the Lab

Run this command to start the cluster with the faults already in place:

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-03/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-015-lab-040-03-02
```
