# Overview: Enforce mTLS With PeerAuthentication At Three Scopes (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- Two namespaces, one meshed and one deliberately not:
  - **`mtls-demo`** (injected) — `booking-service-v1`,
    `notification-service-v1`, and a `tester` client pod, all with sidecars.
  - **`outside`** (no injection) — one `outside-client` pod with `curl` and no
    sidecar, so everything it sends is plaintext.
- **No `PeerAuthentication` anywhere.** The effective mode is the default,
  `PERMISSIVE`, which is why both callers currently succeed.

## Things to try

- Call `notification-service` from both clients before changing anything, and
  note that the response gives no hint which one was encrypted.
- Apply `STRICT` at each of the three scopes in turn, and at each step predict
  the two results before running the calls.
- Put a mesh-wide policy in `mtls-demo` instead of `istio-system` and work out
  from behaviour alone what it actually became.
- Add a `selector` to a namespace-wide policy and see how much stops being
  covered.
- Set `mode: DISABLE` on one workload while the mesh says `STRICT`, then call it
  from `tester`. Predict first.
- Use `portLevelMtls` to make one port permissive on an otherwise strict
  workload.
- Watch `istioctl proxy-config listener ... --port 8084 -o json` change as you
  apply and delete policies — no pod restarts involved.
- Time how long a policy takes to take effect, and how long deleting it takes to
  undo.

## When you're done

```sh
astrona destroy ats-015-playground-010-02
```

(`astrona destroy` takes the environment name, not the config path.)
