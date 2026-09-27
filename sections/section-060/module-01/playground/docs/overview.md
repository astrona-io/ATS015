# Overview: Authorization In Ambient Mode, L4 And L7 (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the **`ambient`** profile — istiod plus the
  `ztunnel` DaemonSet, and **no sidecars anywhere** — plus the Gateway API CRDs
  and `istioctl` on your PATH.
- One namespace, **`ambient-authz`**, labelled
  `istio.io/dataplane-mode=ambient` so its pods are enrolled:
  - `notification-service-v1` — container port `8084`, Service on port 80.
  - `tester` — a `curl` pod running as service account **`tester-sa`**.
  - `other-client` — a `curl` pod running as service account **`other-sa`**.
- **No waypoint and no `AuthorizationPolicy`.** Enrolment is a precondition;
  the policies and the waypoint are yours to build.

## Things to try

- Confirm enrolment before anything else:
  `istioctl ztunnel-config workload --namespace ambient-authz` should show
  `HBONE`.
- Apply an identity-only `ALLOW` and confirm ztunnel enforces it with no
  waypoint. Note the failure shape for the denied client.
- Add a `methods:` rule with no waypoint present. It is accepted and ignored —
  the ambient behaviour worth meeting once, deliberately.
- Deploy the waypoint and re-run the identical request. Nothing about the policy
  changed.
- Delete the waypoint and watch the L7 rule go quiet while the L4 rule survives.
- Attach the L7 policy with `targetRefs` to the Gateway instead of the Service
  and compare.
- Use a label `selector` for the L7 policy and work out from the results what it
  attached to.
- Add a JWT rule and confirm it needs a waypoint for the same reason a method
  rule does.
- Deploy a waypoint **without** enrolling the namespace or service, and check
  whether any traffic reaches it.
- Compare `istioctl ztunnel-config policy` against
  `kubectl get authorizationpolicy` — which policies does ztunnel actually hold?

## When you're done

```sh
astrona destroy ats-015-playground-060-01
```

(`astrona destroy` takes the environment name, not the config path.)
