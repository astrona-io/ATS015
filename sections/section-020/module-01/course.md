# Authorize HTTP Traffic Between Workloads

Astronaut, the secret handshake is already in place. Mutual TLS (mTLS) makes both ships show their ID badges before they talk, so every ship on the planet knows **who** is calling. But knowing who is calling is not the same as letting them in. Right now any ship with a valid badge may send any signal to any other ship.

This module puts a guard at every airlock. The guard works from a list called an `AuthorizationPolicy`: who may come aboard, and what they may do once inside. You will close a whole planet with one empty list, then open exactly the doors the fleet needs, and nothing more.

> An `AuthorizationPolicy` is the guard's list at the airlock. Once a guest list exists for a ship, anyone not on it stays outside.

The surprising part is not a field at all. With no list, the guard lets everyone in. The moment the first `ALLOW` list names a ship, the guard turns strict, and everything not written down is refused.

## How this module is organised

1. **[The Guard At The Airlock](./course-01-the-guard-at-the-airlock.md)**: where the decision is made, which component makes it, and why a ship with no policy lets everyone in.
2. **[Close The Airlock](./course-02-close-the-airlock.md)**: the allow-nothing policy, the rule that the first `ALLOW` creates default-deny, and why `spec: {}` and `rules: [{}]` do opposite things.
3. **[Write A Guest List Entry](./course-03-write-a-guest-list-entry.md)**: the three parts of a rule (`from`, `to`, `when`), how they combine, and how paths are matched.
4. **[Name The Caller](./course-04-name-the-caller.md)**: `principals` and `namespaces`, why both need mTLS, and what happens when several `ALLOW` lists name one ship.
5. **[Least Privilege For The Whole Fleet](./course-05-least-privilege-for-the-fleet.md)**: one guest list per ship, so each ship can only be called by the ship that really needs it.
6. **[Find Out Why The Guard Says No](./course-06-find-out-why-the-guard-says-no.md)**: the flight log, the proxy's own orders and `istioctl analyze`, to tell a wrong rule from a list that never arrived.
7. **[Wrap-Up: Mission Debrief](./course-07-wrap-up.md)**: a recap, check-yourself questions and cleaning up.

Parts 4 and 6 each end with a graded mission.

## Learning objectives

After this module you can:

- Name the component that enforces authorization, say on which side of the signal it runs, and explain why the caller learns almost nothing from a denial.
- Explain what an `AuthorizationPolicy` with an empty `spec: {}` does, field by field, and why it is the usual deny-by-default starting point.
- State the rule that creates default-deny, and predict what a workload with no policy allows.
- Tell `spec: {}` (allow nothing) apart from `rules: [{}]` (allow everything).
- Write `ALLOW` rules on `from.source`, `to.operation` and `when`, and say how values, fields, parts and rules combine.
- Write a `principals` rule from a workload's service account, and explain why it needs mTLS to match.
- Predict the result when two `ALLOW` policies select the same workload.
- Give every service of an application its own least-privilege policy.
- Tell an authorization denial (`403`) apart from a transport rejection, and a wrong rule apart from a policy that never reached the proxy.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, know what is waiting in your playground, and have three small helpers ready in your terminal.

### What you should already know

- **Workload identity.** Every ship with a sidecar gets an ID badge (a certificate) from mission control. The name on the badge comes from the ship's service account, its registration papers, and looks like `spiffe://cluster.local/ns/starfleet/sa/shuttle`.
- **mTLS and `PeerAuthentication`.** In `STRICT` mode, a ship accepts only signals that come with the secret handshake. A caller with no sidecar is cut off before any other check runs.
- **Kubernetes basics.** Namespaces, Deployments, Services, service accounts, pod labels and `kubectl exec`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** already installed, and two planets (namespaces).

| Planet | Ship | Service account | What it does |
| --- | --- | --- | --- |
| `starfleet` | `bridge` | `starfleet-bridge` | The flagship page; it calls `cargo` and `scout` |
| `starfleet` | `cargo` | `starfleet-cargo` | The supply ship |
| `starfleet` | `scout` v1, v2, v3 | `starfleet-scout` | Three ship classes; v2 and v3 ask `navcom` for star ratings |
| `starfleet` | `navcom` | `starfleet-navcom` | The navigation computer |
| `starfleet` | `shuttle` | `shuttle` | Your client: most test signals are sent from here |
| `starfleet` | `fortio` | `default` | A second client with another identity |
| `starfleet` | `probe` v1, v2 | `probe` | The echo probe on port `8000`: it sends back what it receives |
| `outpost` | `drifter` | (none) | An old ship with no sidecar and no ID badge |

Every ship on `starfleet` shows `2/2`: the app plus its communications officer (the `istio-proxy` sidecar). The planet already has a **`PeerAuthentication` in `STRICT` mode**. That is the precondition, not the subject: identity rules need a checked badge. There is **no** `AuthorizationPolicy` yet, so every signal that passes the handshake gets in.

You can also watch the bridge page in your browser at `http://127.0.0.1:9080/productpage`. It breaks and comes back as you add policies.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Three helpers to paste first

Paste these into each new terminal. Each comment says what the helper does:

```sh
# 3 signals from the shuttle (service account shuttle); prints each status code
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- $*"; }
# 1 signal from fortio (service account default); prints the status code
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
# 1 signal from the drifter on the outpost (no sidecar, no identity); prints the status code
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" "$@"; }
```

Use them like this: `from_shuttle http://probe:8000/get`, `from_fortio http://probe:8000/get`, and `from_drifter http://probe.starfleet:8000/get`. The drifter lives on another planet, so its address needs the namespace.

## Why this matters

mTLS answers "who is calling?". Authorization answers "may they?". On the exam you write these policies by hand on a live cluster, and you prove them with one signal that gets in and one that is turned away.

Almost every authorization mistake comes from one of three ideas in this module: that the first `ALLOW` closes the door, that an empty rule and an empty rule list are opposites, and that more `ALLOW` policies can only let more in. Get those right here, and every later policy you write is a few new fields on a familiar object.
