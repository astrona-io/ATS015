# Overview: Authorize HTTP Traffic Between Workloads (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- One injected namespace, **`authz-demo`**:
  - `booking-service-v1` — service account **`booking-sa`**, serves `POST /book`.
  - `notification-service-v1` — service account `default`, serves `POST /notify`.
  - `tester` — a `curl` pod, also service account `default`.
  - All three listen on container port `8084`.
- A **`PeerAuthentication` in `STRICT` mode**, applied at bootstrap. It is a
  precondition, not the subject: `principals` rules need a verified identity.
- **No `AuthorizationPolicy`.** Everything is currently allowed.

## Things to try

- Call every service from every client before writing a policy, so you know what
  "open" looks like.
- Apply `spec: {}` and confirm the whole namespace closes. Read the response
  body, not just the status code.
- Open a single door with one `ALLOW` rule, then try the same path with a
  different method.
- Write a `principals` rule, then delete the `PeerAuthentication` and watch the
  rule stop matching — identity-based authorization without mTLS.
- Give `tester` the `booking-sa` service account and see it inherit the
  permission. Identity is not about pod names.
- Write a rule for `paths: ["/notify"]` and call `/notify/urgent`. Then try
  `["/notify*"]`.
- Add a second `ALLOW` policy that looks more restrictive and confirm it permits
  more, not less.
- Break the `selector` deliberately (a typo in the label value) and use
  `istioctl proxy-config listener` to tell "wrong rule" from "never arrived".

## When you're done

```sh
astrona destroy ats-015-playground-020-01
```

(`astrona destroy` takes the environment name, not the config path.)
