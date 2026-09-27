# Overview: Authenticate End Users With JWT (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- One injected namespace, **`jwt-demo`**:
  - `booking-service-v1` — service account `booking-sa`.
  - `notification-service-v1` — serves `POST /notify`.
  - `tester` — a `curl` pod.
- **No `RequestAuthentication` and no `AuthorizationPolicy`.**

> **Outbound internet required.** This module uses Istio's published demo token
> and the matching JWKS endpoint on `raw.githubusercontent.com`. You fetch the
> token; the proxy fetches the keys. Without outbound access you will see
> key-fetch failures instead of the behaviour the module describes.

## Things to try

- Fetch the demo token, then decode its middle section
  (`echo "$TOKEN" | cut -d. -f2 | base64 -d`) and read `iss`, `sub`, `exp` and
  `groups` before any policy exists.
- Apply only the `RequestAuthentication` and confirm a tokenless request still
  returns `200`. This is the behaviour worth being surprised by once.
- Add a trailing slash to the `issuer` and watch every token start failing with
  `401`, with nothing in the message to say why.
- Point `jwksUri` at a host that does not resolve, then look for the evidence in
  the proxy and istiod logs rather than the application's.
- Require a token with `requestPrincipals: ["*"]`, then narrow it to the exact
  `<issuer>/<subject>` value and see which calls survive.
- Replace `jwksUri` with an inline `jwks` block and confirm the dependency on
  the network is gone.
- Combine `principals` and `requestPrincipals` in one rule, so a call needs both
  the right workload and a valid user.

## When you're done

```sh
astrona destroy ats-015-playground-030-01
```

(`astrona destroy` takes the environment name, not the config path.)
