# DENY Policies And Evaluation Order

An `AuthorizationPolicy` is an Istio resource that allows or denies requests to a workload. The sidecar proxy (Envoy) is a proxy container that Istio adds to each pod; all traffic of the pod passes through it. The sidecar proxy of the receiving pod checks the policies for every request.

You may already know one kind of policy: `action: ALLOW`. Each `ALLOW` policy you add lets more requests in. Sooner or later, though, you need the opposite: "this path stays closed, whatever any other policy says." You write that with `action: DENY`, and everything about it follows from one fact. The sidecar proxy always checks `DENY` policies **before** `ALLOW` policies.

That makes a `DENY` the strongest tool in authorization. No `ALLOW` policy can undo it, so it is a good backstop and a dangerous mistake. A `DENY` that is a little too wide blocks real work at once, and no `ALLOW` can fix it. A `DENY` that is a little too narrow leaves open the path you wanted closed, and nothing warns you. Exam questions often come down to this order: "an `ALLOW` and a `DENY` both fit the same request; what happens?"

This module answers that question in six parts. **DENY Is Checked Before ALLOW** walks through the `CUSTOM`, `DENY`, `ALLOW` order and puts a lone `DENY` on a workload. **An ALLOW Cannot Override A DENY** adds an `ALLOW` that fits and still loses, and shows how the access log tells two `403` responses apart. **Deny All Traffic With One Empty Rule** compares `spec: {}`, `rules: [{}]` and the empty `DENY` rule.

The next three parts turn the order into working policies. **Deny A Path With Prefix Matching** shows the gap an exact path leaves, and ends with the lab *Close A Path With DENY*. **Negative Fields In A DENY Policy** reads `notMethods`, `notPaths` and `notPrincipals` inside a `DENY`, and ends with the lab *Make The Probe Read-Only*. **AUDIT, And Choosing ALLOW Or DENY** tries a rule without enforcing it and settles which design a requirement needs. A short summary closes the module.

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

You need to know the parts of an `AuthorizationPolicy`. A `selector` picks the pods the policy protects; with no selector, it covers every pod in the namespace. The `action` says what to do on a match. The `rules` hold the conditions: `from` (who sends the request), `to` (which method and path it asks for) and `when` (extra conditions). A request fits the policy if **any** rule fits, and inside one rule every part must fit.

You also need two facts about `ALLOW` policies and identity. As soon as one `ALLOW` policy selects a pod, the sidecar proxy refuses everything that no `ALLOW` rule matches, with `403`; this is called default-deny. With mutual TLS (mTLS), both sides present a certificate and check the other one, so the sidecar proxy knows the caller's identity. That identity looks like `cluster.local/ns/<namespace>/sa/<service account>`, and it goes in the `principals` field.

Your playground is one `kind` cluster with **Istio 1.30.5** installed with Helm. You work in the namespace **`starfleet`**, where the Starfleet sample app runs:

| Workload | Its role in this module |
| --- | --- |
| `shuttle` | **The test client**. You send most test requests from here. Its identity is `cluster.local/ns/starfleet/sa/shuttle` |
| `fortio` | A **second caller** with another identity: `cluster.local/ns/starfleet/sa/default` |
| `probe` v1, v2 | The **HTTP echo server** on port `8000`, the workload you protect. `/get`, `/post`, `/delete`, `/status/<code>` and `/anything/<any path>` all answer |
| `bridge`, `cargo`, `scout` v1/v2/v3, `navcom` | The rest of the sample app, each with its own service account |
| `drifter` (namespace `outpost`) | A client pod with **no** sidecar proxy and no certificate, so no identity |

A `PeerAuthentication` in `STRICT` mode is already in place in `starfleet`, so every caller must use mTLS and the sidecar proxy can trust the caller identities. Mesh-wide access logs are on, so every proxy writes one log line per request. There is **no `AuthorizationPolicy` yet**: everything inside `starfleet` is allowed.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Helpers for your terminal

Every part sends the same kinds of test requests, so three short shell helpers save a lot of typing. Paste them into each new terminal before you start:

```sh
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- shuttle $*"; }
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
probe_guard_log() { sleep 5; kubectl logs -n starfleet -l app=probe -c istio-proxy --since=60s | grep "$1" | sort | tail -1; }
PROBE=http://probe:8000
```

`from_shuttle $PROBE/get` sends three requests from the shuttle and prints each status code. `from_fortio $PROBE/get` sends one request from fortio and prints its status code, for example `Code 200`. Both pass extra options on, for example `-X POST`. `probe_guard_log status/200` prints the newest access log line for that path from the probe's sidecar proxy. The proxy writes its log in small batches, so the helper waits five seconds before it reads.

After every `kubectl apply`, **wait up to about a minute** before you trust a test. New connections get the new policy at once, but a connection that was already open keeps the old rules for a while. If you test too early, you see a mix like `200 200 403`. On our test system the mix lasted about 50 seconds.
