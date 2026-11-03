# Authorize TCP Traffic

An `AuthorizationPolicy` is an Istio resource that allows or denies requests to a workload. Most examples use HTTP, where a rule can name a method such as `GET` or a path such as `/admin`. Many workloads do not speak HTTP. A database, a message broker or a custom protocol sends plain TCP bytes, and the sidecar proxy (Envoy), the proxy container Istio adds to each pod, sees only a connection, not a request.

A policy still protects those workloads, but fewer fields apply. A rule that uses an HTTP-only field on a TCP workload does not fail with an error. Istio accepts the object, and the proxy handles the field in a way that surprises most people: an `ALLOW` rule with such a field never matches, and a `DENY` rule with such a field can close a whole workload. Exam questions test this directly.

This module answers the question in three parts. **Which Fields A TCP Rule Can Use** names the fields that exist on a connection and deploys a TCP server. **Allow By Port And Identity** writes `ALLOW` policies that match ports and callers, and shows what default-deny does to a port the Service does not list. **HTTP Fields In TCP Rules** shows what `methods` does inside an `ALLOW` rule and inside a `DENY` rule, and why a `DENY` should name a port. A short summary closes the module.

## Learning objectives

After this module you can:

- Name the `AuthorizationPolicy` fields that work on TCP traffic and the fields that apply to HTTP only.
- Write an `ALLOW` policy that limits a TCP workload to named ports and to named callers.
- Predict what an `ALLOW` policy does to a port that the Kubernetes Service does not list.
- Predict the result of an HTTP-only field inside an `ALLOW` rule and inside a `DENY` rule.
- Scope a `DENY` rule to one port so it does not close the whole workload.

## Before you start

You need the parts of an `AuthorizationPolicy`. A `selector` picks the pods the policy protects. The `action` says what to do on a match. The `rules` hold the conditions: `from` (who connects), `to` (what they connect to) and `when` (extra conditions). Once one `ALLOW` policy selects a pod, the sidecar proxy refuses everything that no `ALLOW` rule matches. A `DENY` policy is checked before any `ALLOW` policy.

You also need one fact about identity. With mutual TLS (mTLS), both sides of a connection present a certificate, so the receiving sidecar proxy knows the caller's identity. That identity has the form `cluster.local/ns/<namespace>/sa/<service account>` and goes in the `principals` field.

Your playground is a `kind` cluster with **Istio 1.30.5** installed with Helm. You work in the namespace **`starfleet`**:

| Workload | Its role in this module |
| --- | --- |
| `tcp-echo` | **The protected TCP server.** It listens on ports `9000`, `9001` and `9002` and replies with `hello` and the text you send. Its Service lists only `9000` and `9001` |
| `shuttle` | **The first client.** Identity `cluster.local/ns/starfleet/sa/shuttle` |
| `relay` | **The second client.** Identity `cluster.local/ns/starfleet/sa/relay` |
| `drifter` (namespace `outpost`) | A client with **no** sidecar proxy, so no identity |

A `PeerAuthentication` in `STRICT` mode is already in place in `starfleet`, so every caller uses mTLS and its identity can be trusted. There is **no `AuthorizationPolicy` yet**.

Launch your playground now and keep it running while you read:

<!-- astrona:playground -->

## Helpers for your terminal

Paste this into each new terminal. It sends the text `port <number>` from one client to a host and port, and prints whether a reply with `hello` came back:

```sh
tcp_from() { out=$(kubectl exec -n starfleet deploy/$1 -c $1 -- sh -c "echo 'port $3' | nc -w 3 $2 $3" 2>&1); case "$out" in *hello*) echo "$1 -> $2:$3 allowed ($out)";; *) echo "$1 -> $2:$3 refused";; esac; }
ECHO_IP=$(kubectl get pod -n starfleet -l app=tcp-echo -o jsonpath='{.items[0].status.podIP}')
```

`tcp_from shuttle tcp-echo 9000` connects from the shuttle to the Service on port 9000. `tcp_from shuttle $ECHO_IP 9002` connects to the pod IP on port 9002. After every `kubectl apply`, wait up to about a minute before you trust a test. A connection that was already open keeps the old rules for a while.
