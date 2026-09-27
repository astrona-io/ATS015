# Overview: Inspect Workload Identity And Certificates (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` and
  `openssl` on your PATH.
- One injected namespace, **`identity-demo`**:
  - `booking-service-v1`, running as the service account **`booking-sa`**.
  - `notification-service-v1` and a `tester` client pod, neither of which
    declares a service account — so both run as **`default`** and share one
    mesh identity.
- **No `PeerAuthentication` and no `AuthorizationPolicy`.** Certificates are
  issued anyway; identity does not wait for a policy to use it.

## Things to try

- Extract `booking-service-v1`'s leaf certificate and read the SAN, then do the
  same for `tester`. Predict both identities before you look.
- Scale `booking-service-v1` to three replicas and check whether the SAN differs
  between pods.
- Give `tester` its own ServiceAccount, restart it, and watch the identity
  change — then find every place the old string would have been written down.
- Apply an `AuthorizationPolicy` with `spiffe://` left on the front of the
  principal. It is accepted, and it matches nothing. Learn that failure
  signature here rather than in an exam.
- Compare `istioctl proxy-config secret` output for a workload against
  `ROOTCA` — one is who this pod is, the other is who it trusts.
- Delete the `istiod` Deployment and watch how long the mesh keeps working.
  (Bring it back with `istioctl install --set profile=demo -y`.)

## When you're done

```sh
astrona destroy ats-015-playground-010-01
```

(`astrona destroy` takes the environment name, not the config path.)
