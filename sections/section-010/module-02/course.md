# Enforce mTLS With PeerAuthentication At Three Scopes

Astronaut, every ship in the mesh already carries an ID badge. The badge office at mission control (`istiod`) signs a certificate for each one, printed from the ship's registration papers (its service account), and the ship's communications officer (the sidecar proxy) shows it whenever it talks to another ship in the mesh. Both ships check each other's badge. This is **mTLS**, short for mutual Transport Layer Security: a secret handshake both ships check before they talk, and the signal between them is locked so nobody else can read it.

Here is the catch. Out of the box, a ship also accepts signals from anyone who does **not** know the handshake. That keeps old ships working, but it means the handshake is optional. A `PeerAuthentication` is the object that makes it required: the rule on a ship's airlock that says who must do the handshake before docking. It has one important field, the mode. The hard part is not the field but the **scope**: the same few lines of YAML cover the whole mesh, one namespace or a few pods, depending only on where you put them and whether they have a `selector`.

## Learning objectives

After this module you can:

- Explain what `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET` each do, and which one applies when no policy exists.
- Show that a signal used mTLS by reading the caller's identity in the `X-Forwarded-Client-Cert` header.
- Recognise the failure a caller without a sidecar sees under `STRICT` (a reset connection, `curl` exit code `56`) and tell it apart from a `403`.
- Write a `PeerAuthentication` at mesh, namespace and workload scope, and predict which one wins.
- Read the mode a pod really uses with `istioctl x describe pod` and `istioctl proxy-config listener`.
- Open one port with `portLevelMtls`, keyed by the container port, on an otherwise strict workload.
- Explain why `PeerAuthentication` only controls the receiving side, and fix a `503 UC` caused by a `DestinationRule` with `tls.mode: DISABLE`.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you know the basics below, see what is waiting in your playground, and paste two small helpers into your terminal.

### What you should already know

- **How the mesh works.** A proxy (the communications officer) sits beside every pod, and `istiod` (mission control) sends it orders.
- **Workload identity.** Every ship's identity comes from its Kubernetes service account. It is written as a SPIFFE ID, for example `spiffe://cluster.local/ns/starfleet/sa/shuttle`. SPIFFE is a standard way to write a workload's name so that any system can read it.
- **Kubernetes basics.** Namespaces, labels, Deployments, Services, and the difference between a Service port and the container port behind it.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** already installed. It has two planets (namespaces):

| Planet | Ships | Sidecar |
| --- | --- | --- |
| `starfleet` | The Starfleet: `bridge`, `cargo`, `scout` v1/v2/v3 and `navcom` on port `9080`; your client `shuttle`; the echo `probe` v1/v2 | Yes, every pod shows `2/2` |
| `outpost` | The `drifter`, an old ship with the same `curl` tool as the shuttle | **No**, it shows `1/1` |

The drifter is the most important ship in this module. It has no communications officer, so it cannot do the handshake. Every signal it sends is plain text. Without a caller like that, every test returns `200` and proves nothing.

The probe answers on Service port `8000`, and its pods listen on container port `8080`. Its `/headers` page echoes the headers a signal arrived with, which is how you will see whether a signal used mTLS.

There is **no** `PeerAuthentication` and **no** `DestinationRule` yet. Writing them is your mission in this module.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Two helpers to paste first

Paste this into each new terminal. `from_shuttle` sends one signal from inside the mesh. `from_drifter` sends one from outside the mesh and also prints `curl`'s exit code, where `56` means the connection was reset:

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" --max-time 5 "$@"; }
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}" --max-time 5 "$@" 2>/dev/null; echo "  exit=$?"; }
PROBE_URL=http://probe.starfleet:8000/get
SCOUT_URL=http://scout.starfleet:9080/reviews/0
```

Use them like this: `from_shuttle $PROBE_URL` or `from_drifter $SCOUT_URL`.

## The parts of this module

Read the parts in this order. Three of them end with a graded mission.

1. [Two Callers, One Default](./course-01-two-callers-one-default.md): what mTLS adds, why both callers get in today, and how one port accepts two kinds of signal.
2. [Require The Handshake With STRICT](./course-02-require-the-handshake.md): the four modes, and the reset connection a caller without a sidecar gets.
3. [Three Scopes, Narrowest Wins](./course-03-three-scopes-narrowest-wins.md): mesh, namespace and workload scope, and which policy decides.
4. [Read The Mode Off The Ship](./course-04-read-the-mode-off-the-ship.md): prove which mode a pod really uses, instead of guessing from a status code.
5. [An Exception For One Port](./course-05-an-exception-for-one-port.md): `portLevelMtls`, and why its key is the container port.
6. [Client And Server Must Agree](./course-06-client-and-server-must-agree.md): the `DestinationRule` side, auto mTLS, `503 UC` and `DISABLE`.
7. [Wrap-Up: Mission Debrief](./course-07-wrap-up.md): what you learned, your missions, and cleaning up.

## Why this matters

`PeerAuthentication` is the first security object most exam tasks touch, and almost every later rule depends on it. A rule that allows "only the shuttle" checks the shuttle's identity, and that identity only exists on signals that used mTLS. Get the mode and scope right here, and the rules you write later have something real to check.
