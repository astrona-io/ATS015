# DENY Policies And Evaluation Order

Astronaut, every ship in the fleet has a guard at its airlock. The guard holds a list, the `AuthorizationPolicy`, that says who may come aboard and what they may do. So far you may know one kind of list: the guest list, written with `action: ALLOW`. Each guest list you add lets more signals in.

Sooner or later a mission needs the opposite: "this door stays shut, whatever anyone else wrote." That is a banned list, written with `action: DENY`. Everything about it follows from one fact: the guard always reads the banned list **before** the guest list.

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

Every mission starts with a pre-flight check. Make sure you know the basics below, know what is waiting in your playground, and have the helpers ready in your terminal.

### What you should already know

- **The parts of an `AuthorizationPolicy`.** A `selector` picks the pods (no selector means every pod in the namespace). `action` says what to do on a match. `rules` hold the conditions: `from` (who sends the signal), `to` (which method and path it asks for) and `when` (extra conditions). The request fits if **any** rule fits. Inside one rule, every part must fit.
- **Default-deny.** As soon as one `ALLOW` policy selects a pod, the guard turns strict: anything not on a guest list gets `403`.
- **Identity.** With mutual TLS (mTLS, a secret handshake where both ships show their ID badge), the guard knows the caller's name. It looks like `cluster.local/ns/<namespace>/sa/<service account>` and goes in the `principals` field.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** installed with Helm. You work on the planet (namespace) **`starfleet`**, where the Starfleet lives:

| Ship | Its role in this module |
| --- | --- |
| `shuttle` | **Your shuttle**. You send most test signals from here. Its ID badge reads `cluster.local/ns/starfleet/sa/shuttle` |
| `fortio` | A **second caller** with another badge: `cluster.local/ns/starfleet/sa/default` |
| `probe` v1, v2 | The **echo probe** on port `8000`, the ship you protect. `/get`, `/post`, `/delete`, `/status/<code>` and `/anything/<any path>` all answer |
| `bridge`, `cargo`, `scout` v1/v2/v3, `navcom` | The rest of the fleet, each with its own service account |
| `drifter` (planet `outpost`) | An old ship with **no** communications officer and no ID badge |

A `PeerAuthentication` in `STRICT` mode is already in place on `starfleet`. Every caller must do the secret handshake, so the guard can trust the names on the badges. Mesh-wide access logs are on, so every proxy keeps a flight log. There is **no `AuthorizationPolicy` yet**: everything inside `starfleet` is allowed.

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

- `from_shuttle $PROBE/get` sends three signals from the shuttle and prints each status code. Extra `curl` options are passed on, for example `-X POST`.
- `from_fortio $PROBE/get` sends one signal from fortio and prints its status code, for example `Code 200`. Extra fortio options are passed on, for example `-X POST`.
- `probe_guard_log status/200` prints the probe's newest flight log line for that path. The proxy writes its log in small batches, so the helper waits five seconds before it reads.

After every `kubectl apply`, **wait up to about a minute** before you trust a test. New connections get the new policy at once. But a connection that was already open keeps the old rules for a while. If you test too early, you see a mix like `200 200 403`. On our test system the mix lasted about 50 seconds.

## How this module is organised

Read the parts in this order. Each one ends with something you have seen work in your playground.

1. **[The Guard Checks The Banned List First](./course-01-the-guard-checks-the-banned-list-first.md)**: the `CUSTOM`, `DENY`, `ALLOW` order, and a ship that has only a banned list.
2. **[A Guest List Cannot Overrule The Ban](./course-02-a-guest-list-cannot-overrule-the-ban.md)**: an `ALLOW` that fits and still loses, and how the flight log tells two `403`s apart.
3. **[Lock Everything With One Empty Rule](./course-03-lock-everything-with-one-empty-rule.md)**: `spec: {}`, `rules: [{}]` and the empty `DENY` rule.
4. **[Close The Whole Path](./course-04-close-the-whole-path.md)**: exact and prefix paths, and the hole an exact path leaves. Mission: *Close A Path With DENY*.
5. **[Say It Out Loud: Negative Fields](./course-05-say-it-out-loud-negative-fields.md)**: `notMethods`, `notPaths` and `notPrincipals` inside a `DENY`. Mission: *Make The Probe Read-Only*.
6. **[AUDIT, And Choosing ALLOW Or DENY](./course-06-audit-and-choosing-allow-or-deny.md)**: trying a rule without enforcing it, and which design a requirement needs.
7. **[Wrap-Up: Mission Debrief](./course-07-wrap-up.md)**: what you learned, your missions, questions to check yourself, and cleaning up.

## Why this matters

A banned list is the strongest tool the guard has. No guest list can undo it, which makes it a perfect backstop and a dangerous mistake. A `DENY` that is a little too wide blocks real work at once, and no `ALLOW` can rescue it. A `DENY` that is a little too narrow leaves the door you wanted shut wide open, and nothing warns you.

This module trains the habit that prevents both: predict the guard's answer from the order, then prove it with one signal that must pass and one that must be refused.
