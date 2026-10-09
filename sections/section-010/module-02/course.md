# Enforce mTLS With PeerAuthentication At Three Scopes

Every workload in the mesh already has a certificate. `istiod`, Istio's control plane, signs a certificate for each workload, based on its Kubernetes service account. The workload's sidecar proxy (Envoy), a proxy container that Istio adds to each pod, presents this certificate when it connects to another workload in the mesh. Both sides check each other's certificate. This is **mTLS**, short for mutual Transport Layer Security: both sides present a certificate, so the connection is encrypted and both identities are verified.

There is a catch, though. By default, a workload also accepts plain-text requests from callers that do **not** use mTLS. That keeps older workloads working, but it means mTLS is optional. A `PeerAuthentication` is the object that makes it required: it sets whether a workload accepts plain text, mTLS or both on inbound connections. Its one important field is the mode. The hard part is not the field but the **scope**: the same few lines of YAML cover the whole mesh, one namespace or a few pods, depending only on where you put them and whether they have a `selector`.

This module takes `PeerAuthentication` apart in six parts. **Two Callers, One Default** shows what the mesh does before any policy exists, and how to tell a protected request from an unprotected one. **Require mTLS With STRICT** makes mTLS required and shows the failure a caller without a certificate sees. **Three Scopes, Narrowest Wins** explains how one policy becomes mesh-wide, namespace-wide or workload-wide, and which one wins. **Read The mTLS Mode A Pod Uses** asks the sidecar proxy which policy it really follows. **An Exception For One Port** opens a single port on a strict workload. **Client And Server Must Agree** turns to the sending side, where a `DestinationRule` can break mTLS.

`PeerAuthentication` is the first security object most exam tasks touch, and almost every later rule depends on it. A rule that allows "only the shuttle" checks the shuttle's identity, and that identity only exists on requests that used mTLS. When the mode and the scope are right, the rules you write later have something real to check.

## Learning objectives

After this module you can:

- Explain what `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET` each do, and which one applies when no policy exists.
- Show that a request used mTLS by reading the caller's identity in the `X-Forwarded-Client-Cert` header.
- Recognise the failure a caller without a sidecar sees under `STRICT` (a reset connection, `curl` exit code `56`) and tell it apart from a `403`.
- Write a `PeerAuthentication` at mesh, namespace and workload scope, and predict which one wins.
- Read the mode a pod really uses with `istioctl x describe pod` and `istioctl proxy-config listener`.
- Open one port with `portLevelMtls`, keyed by the container port, on an otherwise strict workload.
- Explain why `PeerAuthentication` only controls the receiving side, and fix a `503 UC` caused by a `DestinationRule` with `tls.mode: DISABLE`.

## Before you start

You need a rough picture of how the mesh works: a sidecar proxy runs beside every application container in a pod, and `istiod` sends it configuration. You also need to know where a workload's identity comes from. Every workload's identity comes from its Kubernetes service account, and it is written as a SPIFFE ID, for example `spiffe://cluster.local/ns/starfleet/sa/shuttle`. SPIFFE is a standard way to write a workload's name so that any system can read it.

From Kubernetes, you need namespaces, labels, Deployments and Services. You also need the difference between a Service port and the container port behind it, because one part of this module depends on it.

Your playground is one `kind` cluster with **Istio 1.30.5** already installed. It has two namespaces:

| Namespace | Workloads | Sidecar |
| --- | --- | --- |
| `starfleet` | The Starfleet: `bridge`, `cargo`, `scout` v1/v2/v3 and `navcom` on port `9080`; your client `shuttle`; the echo `probe` v1/v2 | Yes, every pod shows `2/2` |
| `outpost` | The `drifter`, a client pod with the same `curl` tool as the shuttle | **No**, it shows `1/1` |

The `drifter` is the most important workload in this module. It has no sidecar, so it has no certificate and cannot use mTLS. Every request it sends is plain text. Without a caller like that, every test returns `200` and proves nothing.

The `probe` answers on Service port `8000`, and its pods listen on container port `8080`. Its `/headers` page echoes the headers a request arrived with, which is how you will see whether a request used mTLS. There is **no** `PeerAuthentication` and **no** `DestinationRule` yet. You write them in this module.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Every part sends test requests with two small shell helpers. `from_shuttle` sends one request from inside the mesh. `from_drifter` sends one from outside the mesh and also prints `curl`'s exit code, where `56` means the connection was reset. Paste them into each new terminal:

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" --max-time 5 "$@"; }
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}" --max-time 5 "$@" 2>/dev/null; echo "  exit=$?"; }
PROBE_URL=http://probe.starfleet:8000/get
SCOUT_URL=http://scout.starfleet:9080/reviews/0
```

You use them like this: `from_shuttle $PROBE_URL` or `from_drifter $SCOUT_URL`.
