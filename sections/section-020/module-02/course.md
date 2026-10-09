# DENY Policies And Evaluation Order

An `AuthorizationPolicy` is an Istio resource that allows or denies requests to a workload. The sidecar proxy (Envoy) is a proxy container that Istio adds to each pod; all traffic of the pod passes through it. The sidecar proxy of the receiving pod checks the policies for every request.

You may already know one kind of policy: `action: ALLOW`. Each `ALLOW` policy you add lets more requests in.

Sooner or later you need the opposite: "this path stays closed, whatever any other policy says." You write that with `action: DENY`. Everything about it follows from one fact: the sidecar proxy always checks `DENY` policies **before** `ALLOW` policies.

Exam questions about authorization often come down to this order. A typical one reads: "an `ALLOW` and a `DENY` both fit the same request; what happens?" The answer never changes, and this module makes sure you know why.

## Learning objectives

After this module you can:

- State the order in which `CUSTOM`, `DENY` and `ALLOW` policies are checked, and what ends the decision at each step.
- Predict the result when an `ALLOW` policy and a `DENY` policy both fit the same request.
- Say what a workload with only `DENY` policies allows, and why that differs from a workload with an `ALLOW` policy.
- Tell a `403` from a `DENY` apart from a `403` from a missing `ALLOW`, using the access log on the receiving side.
- Tell `spec: {}`, `rules: [{}]` and `action: DENY` with `rules: [{}]` apart, and predict what each one does.
- Write a `DENY` rule with prefix matching, and explain why an exact path leaves a hole.
- Read `notMethods`, `notPaths` and `notPrincipals` correctly inside a `DENY`.
- Use `AUDIT` to try a rule without changing any reply, and choose between an `ALLOW`-based and a `DENY`-based design.

## Before you start

This module builds on a few basics. Make sure you know them, know what is in your playground, and have the helpers ready in your terminal.

### What you should already know

- **The parts of an `AuthorizationPolicy`.** A `selector` picks the pods (no selector means every pod in the namespace). `action` says what to do on a match. `rules` hold the conditions: `from` (who sends the request), `to` (which method and path it asks for) and `when` (extra conditions). The request fits if **any** rule fits. Inside one rule, every part must fit.
- **Default-deny.** As soon as one `ALLOW` policy selects a pod, the sidecar proxy refuses everything that no `ALLOW` rule matches, with `403`.
- **Identity.** With mutual TLS (mTLS, where both sides present a certificate and check the other one), the sidecar proxy knows the caller's identity. It looks like `cluster.local/ns/<namespace>/sa/<service account>` and goes in the `principals` field.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5** installed with Helm. You work in the namespace **`starfleet`**, where the Starfleet sample app runs:

| Workload | Its role in this module |
| --- | --- |
| `shuttle` | **The test client**. You send most test requests from here. Its identity is `cluster.local/ns/starfleet/sa/shuttle` |
| `fortio` | A **second caller** with another identity: `cluster.local/ns/starfleet/sa/default` |
| `probe` v1, v2 | The **HTTP echo server** on port `8000`, the workload you protect. `/get`, `/post`, `/delete`, `/status/<code>` and `/anything/<any path>` all answer |
| `bridge`, `cargo`, `scout` v1/v2/v3, `navcom` | The rest of the sample app, each with its own service account |
| `drifter` (namespace `outpost`) | A client pod with **no** sidecar proxy and no certificate, so no identity |

A `PeerAuthentication` in `STRICT` mode is already in place in `starfleet`. Every caller must use mTLS, so the sidecar proxy can trust the caller identities. Mesh-wide access logs are on, so every proxy writes one log line per request. There is **no `AuthorizationPolicy` yet**: everything inside `starfleet` is allowed.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Helpers to paste first

Paste these into each new terminal before you start:

```sh
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- shuttle $*"; }
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
probe_guard_log() { sleep 5; kubectl logs -n starfleet -l app=probe -c istio-proxy --since=60s | grep "$1" | sort | tail -1; }
PROBE=http://probe:8000
```

- `from_shuttle $PROBE/get` sends three requests from the shuttle and prints each status code. Extra `curl` options are passed on, for example `-X POST`.
- `from_fortio $PROBE/get` sends one request from fortio and prints its status code, for example `Code 200`. Extra fortio options are passed on, for example `-X POST`.
- `probe_guard_log status/200` prints the newest access log line for that path from the probe's sidecar proxy. The proxy writes its log in small batches, so the helper waits five seconds before it reads.

After every `kubectl apply`, **wait up to about a minute** before you trust a test. New connections get the new policy at once. But a connection that was already open keeps the old rules for a while. If you test too early, you see a mix like `200 200 403`. On our test system the mix lasted about 50 seconds.

## How this module is organised

Read the parts in this order. Each one ends with something you have seen work in your playground.

1. **[DENY Is Checked Before ALLOW](./course-01-the-guard-checks-the-banned-list-first.md)**: the `CUSTOM`, `DENY`, `ALLOW` order, and a workload that has only `DENY` policies.
2. **[An ALLOW Cannot Override A DENY](./course-02-a-guest-list-cannot-overrule-the-ban.md)**: an `ALLOW` that fits and still loses, and how the access log tells two `403`s apart.
3. **[Deny All Traffic With One Empty Rule](./course-03-lock-everything-with-one-empty-rule.md)**: `spec: {}`, `rules: [{}]` and the empty `DENY` rule.
4. **[Deny A Path With Prefix Matching](./course-04-close-the-whole-path.md)**: exact and prefix paths, and the gap an exact path leaves. Lab: *Close A Path With DENY*.
5. **[Negative Fields In A DENY Policy](./course-05-say-it-out-loud-negative-fields.md)**: `notMethods`, `notPaths` and `notPrincipals` inside a `DENY`. Lab: *Make The Probe Read-Only*.
6. **[AUDIT, And Choosing ALLOW Or DENY](./course-06-audit-and-choosing-allow-or-deny.md)**: trying a rule without enforcing it, and which design a requirement needs.
7. **[Wrap-Up](./course-07-wrap-up.md)**: what you learned, the labs, questions to check yourself, and cleaning up.

## Why this matters

A `DENY` policy is the strongest tool in authorization. No `ALLOW` policy can undo it, which makes it a good backstop and a dangerous mistake. A `DENY` that is a little too wide blocks real work at once, and no `ALLOW` can fix it. A `DENY` that is a little too narrow leaves open the path you wanted closed, and nothing warns you.

This module trains the habit that prevents both: predict the sidecar proxy's answer from the order, then prove it with one request that must pass and one that must be refused.
