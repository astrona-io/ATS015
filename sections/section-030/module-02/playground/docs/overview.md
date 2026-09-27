# Overview: Authorize On JWT Claims (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile, plus `istioctl` on your
  PATH.
- One injected namespace, **`jwtclaims-demo`**:
  - `booking-service-v1` — service account `booking-sa`.
  - `notification-service-v1` — serves `POST /notify`, and has **no `/admin`
    handler**, so an authorized `/admin` request returns `404` from the app.
    Anything that is not `403` means the mesh let it through.
  - `tester` — a `curl` pod.
- A **`RequestAuthentication`** for the Istio demo issuer, applied at bootstrap.
  Tokens are validated; none is required yet.
- **No `AuthorizationPolicy`.**

> **Outbound internet required.** You fetch two demo tokens from
> `raw.githubusercontent.com`, and the proxy fetches the issuer's keys.

## Things to try

- Decode both demo tokens and list every claim before writing a single rule.
  `demo.jwt` has no `groups`; `groups-scope.jwt` has `groups` and `scope`.
- Write a `when` rule with no `requestPrincipals` and see whether a tokenless
  request can reach it.
- Match on `scope` instead of `groups`, then on both at once, and work out
  whether two `when` entries are ANDed or ORed from the results.
- Use `notValues` to exclude a group, and predict what happens for a token that
  has no `groups` claim at all.
- Misspell the claim name (`group` instead of `groups`) and confirm the rule is
  accepted, compiles, and never matches.
- Match on `request.auth.principal` directly and compare with
  `requestPrincipals` in `from.source`.
- Wrap `$TOKEN` in single quotes inside `kubectl exec` and see what the failure
  looks like — it resembles a bad token, not a shell mistake.
- Switch the policy to `DENY` with the same `when` and think through which
  tokens now get through.

## When you're done

```sh
astrona destroy ats-015-playground-030-02
```

(`astrona destroy` takes the environment name, not the config path.)
