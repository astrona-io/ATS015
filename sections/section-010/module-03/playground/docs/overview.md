# Overview: Migrate A Namespace From PERMISSIVE To STRICT mTLS (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- Two namespaces, representing a half-finished mesh adoption:
  - **`migrate-demo`** (injected) — `booking-service-v1`,
    `notification-service-v1` (container port `8084`) and a `tester` client pod.
  - **`outside`** (no injection) — one `outside-client` pod, the caller you
    migrate into the mesh.
- **No `PeerAuthentication`.** `migrate-demo` is implicitly `PERMISSIVE` — the
  mode was never decided, only inherited, which is the realistic starting point.

## Things to try

- Generate traffic from both clients, then read `connection_security_policy` off
  `istio_requests_total` on the receiving proxy. Both values should appear.
- Flip straight to `STRICT` without migrating anything, and watch exactly which
  caller breaks and what the failure looks like from its side. Roll back.
- Label `outside` for injection and check the pod's container list *before*
  restarting it. The label alone changes nothing.
- Read the counters again after migrating. Counters are cumulative — work out
  how you would tell old `none` samples from new ones.
- Write a `portLevelMtls` exception for port `9090`, which nothing listens on.
  It applies cleanly and does nothing: learn that signature here.
- Write the same exception for `8084` instead and watch the whole workload
  become permissive again.
- Add a `DestinationRule` on the `tester` side with `tls.mode: DISABLE` while
  the server is `STRICT`, and see how the failure differs from an unmeshed
  caller's.
- Time a rollback: apply `PERMISSIVE` and measure how quickly traffic recovers.

## When you're done

```sh
astrona destroy ats-015-playground-010-03
```

(`astrona destroy` takes the environment name, not the config path.)
