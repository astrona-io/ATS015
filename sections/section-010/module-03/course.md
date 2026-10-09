# Migrate A Namespace From PERMISSIVE To STRICT mTLS

This module is about one small change with a big effect. Writing `mode: STRICT` takes ten seconds. It tells every workload in a namespace to accept only connections that use mTLS (mutual Transport Layer Security). With mTLS, both sides present a certificate, so the connection is encrypted and both identities are checked. Any client that cannot do mTLS is cut off at once.

The hard part is knowing that the change is safe. A client that still sends plain text breaks the moment the policy lands. It sees a connection reset, and that error shows up in *its* logs, not in yours. So this module teaches a procedure, not a new object: count, write down, move the clients, and only then switch.

## Learning objectives

After this module you can:

- Read the `connection_security_policy` label on `istio_requests_total` from the receiving workload's proxy, and say why you read it there and not on the client.
- Find which client still sends plain text, with the counter's source labels and the receiving workload's access log.
- Say what a counter cannot prove, and how long you should measure.
- Write the current `PERMISSIVE` mode down as a `PeerAuthentication`, and use that file to roll back in seconds.
- Explain why labelling a namespace for sidecar injection changes nothing for pods that are already running.
- Put the steps of a `PERMISSIVE`-to-`STRICT` migration in a safe order, and the steps of an undo in the reverse order.
- Recognise the two typical errors: a connection reset (curl exit code 56) for a client with no sidecar, and `503 UC` when a client-side `DestinationRule` sends plain text.

## Before you start

This section lists what the module expects you to know, and what is waiting in your playground.

### What you should already know

- **How the mesh works.** A sidecar proxy (Envoy) is a proxy container that Istio adds to each pod. All inbound and outbound traffic of the pod passes through it. `istiod`, Istio's control plane, sends configuration and certificates to every proxy.
- **`PeerAuthentication` basics.** It sets the mTLS mode a receiving proxy accepts: `STRICT` (mTLS only), `PERMISSIVE` (mTLS and plain text) or `DISABLE` (plain text only). A policy named `default` with no `selector` covers a whole namespace. A policy with a `selector` covers only the matching pods, and the narrower policy wins. With no policy at all, the mode is `PERMISSIVE`.
- **Kubernetes basics.** Namespaces, Deployments, Services, labels and `kubectl exec`.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5** already installed. It has two namespaces.

**`starfleet`** has sidecar injection switched on. It runs **the Starfleet**: the Bookinfo sample app from the Istio docs, with space names.

| Workload | Its role in this module |
| --- | --- |
| `cargo` | The backend you send test requests to, on port `9080`, path `/details/0` |
| `shuttle` | Your test client. It has a sidecar proxy, so its requests use mTLS |
| `bridge`, `scout`, `navcom`, `probe` | The rest of the sample app. They talk to each other with mTLS and keep working through the whole module |

**`outpost`** has sidecar injection switched **off**, on purpose. Its one pod, **`drifter`**, has no sidecar proxy (`1/1`). It still sends plain-text requests to `cargo`. It is the client that would break if `starfleet` switched to `STRICT` today.

There is **no** `PeerAuthentication` yet, so `starfleet` runs in the default `PERMISSIVE` mode. That is a realistic start: a namespace whose mode was never chosen, only inherited.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### One helper to paste first

Paste this into each new terminal. It reads the request counter of `cargo`'s sidecar proxy and adds up how many requests arrived with mTLS (`mutual_tls`) and how many arrived as plain text (`none`):

```sh
plain_signals() {
  kubectl -n starfleet exec deploy/cargo-v1 -c istio-proxy -- \
    pilot-agent request GET stats/prometheus \
    | grep '^istio_requests_total' | grep 'reporter="destination"' \
    | sed -n 's/.*connection_security_policy="\([^"]*\)".* \([0-9]*\)$/\1 \2/p' \
    | awk '{sum[$1]+=$2} END {for (k in sum) print k, sum[k]}'
}
```

## The parts, in order

1. [Count Plain-Text Requests To A Workload](./course-01-count-the-plain-signals.md): read the receiving proxy's counter, find which client sends plain text, and learn what a counter cannot prove.
2. [Write Down The Current mTLS Mode](./course-02-write-down-where-you-stand.md): write `PERMISSIVE` as a file, run a short `STRICT` test, and roll back. Also the safe order for adding and removing policies.
3. [Inject A Sidecar Into A Plain-Text Client](./course-03-bring-the-drifter-into-the-fleet.md): sidecar injection, why a label is not enough, and measuring again.
4. [Switch The Namespace To STRICT mTLS](./course-04-switch-to-strict-for-good.md): the switch, proof on the proxy, the client-side `DestinationRule` trap, and the rollback plan.
5. [Wrap-Up](./course-05-wrap-up.md): what you learned, the graded lab, and cleaning up.
