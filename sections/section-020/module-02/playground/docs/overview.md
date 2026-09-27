# Overview: DENY Policies And Evaluation Order (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- One injected namespace, **`deny-demo`**:
  - `booking-service-v1` — service account **`booking-sa`**.
  - `notification-service-v1` — serves `POST /notify`, and has **no `/admin`
    handler**, so an unblocked `/admin` request returns `404` from the app. That
    is deliberate: it lets you tell "blocked" (`403`) from "reached the app".
  - `tester` — a `curl` pod.
- A **`PeerAuthentication` in `STRICT` mode**, applied at bootstrap.
- **No `AuthorizationPolicy`.** Everything is currently allowed.

## Things to try

- Apply only a `DENY` policy to a workload with no other policies, then call a
  path it does not mention. Predict first.
- Stack an `ALLOW` that explicitly permits exactly what a `DENY` blocks, and
  confirm the order by result alone.
- Demote the `DENY` to `AUDIT` and watch the conflicting `ALLOW` become
  reachable. Promote it back.
- Write `paths: ["/admin"]` without the `*`, then call `/admin/users`.
- Write a `DENY` with `notPaths: ["/health"]` and work out what is still
  reachable before you test it.
- Deny by `notPrincipals` instead of by path, and compare how the failure looks
  to the caller.
- Delete every policy and re-confirm that a bare workload allows everything —
  the default people misremember.
- Check `istioctl proxy-config listener deploy/notification-service-v1 -n
  deny-demo -o json` for the RBAC filters as you add and remove policies.

## When you're done

```sh
astrona destroy ats-015-playground-020-02
```

(`astrona destroy` takes the environment name, not the config path.)
