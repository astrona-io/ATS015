# Migrate A Namespace From PERMISSIVE To STRICT mTLS

Astronaut, this mission is about one small change with a big blast radius. Writing `mode: STRICT` takes ten seconds. It tells every ship on a planet to accept only signals that come with mTLS (mutual Transport Layer Security). mTLS is a secret handshake: both ships prove who they are before they talk. Any caller that cannot do the handshake is cut off at once.

The hard part is knowing that the change is safe. A caller that still sends plain signals breaks the moment the rule lands. It sees a connection reset, and that error shows up in *its* logs, not in yours. So this module teaches a procedure, not a new object: count, write down, move the callers, and only then switch.

## Learning objectives

After this module you can:

- Read the `connection_security_policy` label on `istio_requests_total` from the receiving ship's proxy, and say why you read it there and not on the caller.
- Find which caller still sends plain signals, with the counter's source labels and the receiving ship's access log.
- Say what a counter cannot prove, and how long you should measure.
- Write the current `PERMISSIVE` mode down as a `PeerAuthentication`, and use that file to roll back in seconds.
- Explain why labelling a namespace for sidecar injection changes nothing for pods that are already running.
- Put the steps of a `PERMISSIVE`-to-`STRICT` migration in a safe order, and the steps of an undo in the reverse order.
- Recognise the two typical errors: a connection reset (curl exit code 56) for a caller with no sidecar, and `503 UC` when a client-side `DestinationRule` sends plain signals.

## Before you start

Every mission starts with a pre-flight check, astronaut. Here is what this module expects you to know, and what is waiting in your playground.

### What you should already know

- **How the mesh works.** A sidecar proxy (the ship's communications officer) sits beside every pod. `istiod` (mission control) sends it its orders. Every signal in or out of the pod goes through the proxy.
- **`PeerAuthentication` basics.** It sets the mTLS mode a receiving proxy accepts: `STRICT` (mTLS only), `PERMISSIVE` (mTLS and plain) or `DISABLE` (plain only). A policy named `default` with no `selector` covers a whole namespace. A policy with a `selector` covers only the matching pods, and the narrower policy wins. With no policy at all, the mode is `PERMISSIVE`.
- **Kubernetes basics.** Namespaces, Deployments, Services, labels and `kubectl exec`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** already installed. It has two planets (namespaces).

**`starfleet`** has sidecar injection switched on. It runs **the Starfleet**: the Bookinfo sample app from the Istio docs, with space names.

| Ship | Its role in this module |
| --- | --- |
| `cargo` | The **supply ship**. It is the ship you send test signals to, on port `9080`, path `/details/0` |
| `shuttle` | **Your shuttle**. It has a communications officer, so its signals use mTLS |
| `bridge`, `scout`, `navcom`, `probe` | The rest of the fleet. They talk to each other with mTLS and keep working through the whole module |

**`outpost`** has sidecar injection switched **off**, on purpose. Its one ship, the **`drifter`**, has no communications officer (`1/1`). It still sends plain signals to `cargo`. It is the caller that would break if `starfleet` switched to `STRICT` today.

There is **no** `PeerAuthentication` yet, so `starfleet` runs in the default `PERMISSIVE` mode. That is a realistic start: a planet whose mode was never chosen, only inherited.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### One helper to paste first

Paste this into each new terminal. It reads `cargo`'s own signal counter and adds up how many signals arrived with mTLS (`mutual_tls`) and how many arrived plain (`none`):

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

1. [Count The Plain Signals](./course-01-count-the-plain-signals.md): read the receiving ship's counter, find which caller sends plain signals, and learn what a counter cannot prove.
2. [Write Down Where You Stand](./course-02-write-down-where-you-stand.md): write `PERMISSIVE` as a file, run a short `STRICT` drill, and roll back. Also the safe order for adding and removing rules.
3. [Bring The Drifter Into The Fleet](./course-03-bring-the-drifter-into-the-fleet.md): sidecar injection, why a label is not enough, and measuring again.
4. [Switch To STRICT For Good](./course-04-switch-to-strict-for-good.md): the switch, proof on the proxy, the client-side trap, and the rollback plan.
5. [Wrap-Up: Mission Debrief](./course-05-wrap-up.md): what you learned, your mission, and cleaning up.
