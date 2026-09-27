# Part 1 — The ambient dataplane

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — What ztunnel can enforce](./course-02-what-ztunnel-can-enforce.md).

Every rule in this module is a consequence of how ambient mode moves traffic. This part is that mechanism: what replaces the sidecar, what it carries, how a pod's traffic reaches it without the pod being changed, and what "enrolled" means as an observable fact.

## Two layers instead of one

In sidecar mode a single proxy in each pod did everything: mTLS, L4 handling, and HTTP parsing for routing, telemetry and policy. You paid for all of it on every workload, whether or not the workload needed L7.

Ambient splits that into two layers you adopt separately:

```text
   ┌──────────────────────────── node ────────────────────────────┐
   │                                                              │
   │   pod A            pod B            pod C                    │
   │   (no sidecar)     (no sidecar)     (no sidecar)              │
   │      │                 │                │                    │
   │      └─── redirected ──┴────────────────┘                    │
   │                    │                                         │
   │              ┌─────▼──────┐                                  │
   │              │  ztunnel   │  DaemonSet, one per node         │
   │              │            │  mTLS over HBONE, L4 policy      │
   │              └─────┬──────┘  does NOT parse HTTP             │
   └────────────────────┼─────────────────────────────────────────┘
                        │
                 optional, per namespace or service
                        │
                 ┌──────▼───────┐
                 │   waypoint   │  an Envoy, deployed only where asked
                 │              │  parses HTTP: L7 policy, routing,
                 └──────────────┘  L7 telemetry
```

**ztunnel** — zero-trust tunnel — runs once per node as a DaemonSet. It establishes mutual TLS between workloads and enforces connection-level policy. It deliberately does not parse HTTP: it sees connections, not requests.

**A waypoint** is a full Envoy, deployed per namespace or per service, and only when something needs L7. It is an ordinary Deployment fronted by a Gateway API `Gateway`, which is why [Part 3](./course-03-waypoints-and-l7-policy.md) creates one with a Gateway API object rather than an Istio-specific one.

The design goal is that you pay for L7 where you need it instead of everywhere. The consequence for security work is that **"is there a waypoint in this path?" becomes a question you must ask before writing any policy** — and nothing in the policy object will ask it for you.

## HBONE

ztunnel does not forward raw TCP between nodes. It wraps a connection in **HBONE** — HTTP-Based Overlay Network Environment — which is a CONNECT-style tunnel over HTTP/2, inside mutual TLS, on port `15008`.

```text
   pod A ──plain TCP──▶ ztunnel(A) ══ mTLS + HTTP/2 CONNECT ══▶ ztunnel(B) ──plain TCP──▶ pod B
                          │                                        │
                   presents A's cert                        verifies it, and
                   (SPIFFE identity,                        learns A's identity
                    from section 010)                        for policy decisions
```

Two things follow, and the second is the one people do not expect:

- **Identity works exactly as in sidecar mode.** The certificates are the same SPIFFE ones from [section 010](../../section-010/module-01/course-01-how-identity-is-issued.md), issued to the same service accounts, and presented on the HBONE connection. So `principals` and `namespaces` rules are fully available at L4 — no waypoint required. That is worth saying twice, because "L7 needs a waypoint" is often over-generalised into "anything useful needs a waypoint".
- **The tunnel is HTTP/2, but the payload is opaque to it.** ztunnel is not parsing the application's HTTP; it is using HTTP/2 CONNECT as the tunnelling mechanism. The inner stream is bytes as far as ztunnel is concerned — the same distinction as a passthrough gateway in [section 040](../../section-040/module-03/course-01-what-a-proxy-can-see.md).

## How traffic gets redirected

A sidecar was in the pod, so `iptables` rules inside the pod's network namespace captured its traffic. Ambient has no sidecar, so redirection happens outside the pod, set up by the **istio-cni** component when a pod is enrolled:

```text
   namespace labelled istio.io/dataplane-mode=ambient
        │
        ▼
   istio-cni (a DaemonSet) notices pods in that namespace
        │
        ▼
   installs redirection for each pod's traffic to the node's ztunnel
        │
        ▼
   the POD IS NOT MODIFIED — no new container, no new spec, no restart
```

That last line is the practical difference from [section 010](../../section-010/module-03/course-02-exceptions-and-meshing.md)'s migration. Sidecar injection is a mutating admission webhook that rewrites the pod spec, so it only applies to pods created afterwards and existing pods need a restart. Ambient enrolment changes node-level networking, so **labelling a namespace enrols its running pods immediately**, with no restart and no disruption.

That is the headline operational advantage of ambient mode, and it is why enrolment is a precondition in this playground rather than an exercise: there is nothing to watch happen.

## Confirming enrolment

"Enrolled" is not a pod-visible fact — there is no extra container to look for. The observable is what ztunnel knows about, and which protocol it is using for each workload.

> [!TIP]
> **Try it — confirm the workloads are enrolled, and that no waypoint exists**
>
> ```sh
> kubectl -n ambient-authz get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> istioctl ztunnel-config workload --namespace ambient-authz
> kubectl -n ambient-authz get gateway
> ```
>
> Expect something like:
>
> ```text
> POD                              CONTAINERS
> notification-service-v1-...      notification-service
> other-client-...                 other-client
> tester-...                       tester
>
> NAMESPACE      POD NAME                    ADDRESS      NODE              WAYPOINT  PROTOCOL
> ambient-authz  notification-service-v1-…   10.244.0.12  kind-control-…    None      HBONE
> ambient-authz  other-client-…              10.244.0.13  kind-control-…    None      HBONE
> ambient-authz  tester-…                    10.244.0.14  kind-control-…    None      HBONE
>
> No resources found in ambient-authz namespace.
> ```
>
> Three things in one screen. **One container per pod** — no `istio-proxy` anywhere, unlike every earlier module. **`PROTOCOL: HBONE`** — ztunnel is carrying this traffic and doing mTLS for it, which is the real meaning of "enrolled". **`WAYPOINT: None`** and an empty `get gateway` — no L7 layer exists yet, which is the starting condition the next two parts depend on.

`istioctl ztunnel-config` is the ambient counterpart of `istioctl proxy-config`, and the `workload` subcommand is its equivalent of "what does this proxy know about". [Part 4](./course-04-tooling-and-carrying-across.md) covers the rest of the family.

> *ztunnel carries mTLS over HBONE and never parses HTTP, so identity is fully available at L4 while anything about a request needs a separate waypoint.*

## Reference

- [Istio ambient mode architecture](https://istio.io/latest/docs/ambient/architecture/) — ztunnel, waypoints, istio-cni and how they fit together.
- [HBONE](https://istio.io/latest/docs/ambient/architecture/hbone/) — the tunnel protocol, its port, and what it carries.
- [Adding workloads to ambient](https://istio.io/latest/docs/ambient/usage/add-workloads/) — the namespace label and what enrolment does to running pods.
