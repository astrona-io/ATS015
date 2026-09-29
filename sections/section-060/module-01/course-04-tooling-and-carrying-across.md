# Part 4 — Tooling, and carrying sidecar knowledge across

> Prerequisite: [Part 3 — Waypoints and L7 policy](./course-03-waypoints-and-l7-policy.md). Next: [the module landing page](./course.md), then [the course README](../../../README.md).

Ambient mode has two enforcement points, and a policy held by neither does nothing. This part is how to ask which component holds what, the traps that follow from the split, and an audit of what the previous five sections still buy you here.

## `istioctl ztunnel-config`

The sidecar-mode habit of `istioctl proxy-config` has a direct counterpart:

| Sidecar mode | Ambient mode | Question |
| --- | --- | --- |
| `proxy-config cluster <pod>` | `ztunnel-config workload` | what does it know about? |
| `proxy-config secret <pod>` | `ztunnel-config certificate` | what TLS material does it hold? |
| `proxy-config listener <pod>` | `ztunnel-config policy` | what policy is it enforcing? |

Waypoints, being ordinary Envoy proxies, are still inspected with `istioctl proxy-config` — pointed at the waypoint Deployment rather than at an application pod.

> [!TIP]
> **Try it — ask ztunnel what policy it is holding**
>
> ```sh
> istioctl ztunnel-config policy --namespace ambient-authz
> kubectl -n ambient-authz get authorizationpolicy
> ```
>
> Expect something like:
>
> ```text
> NAMESPACE       POLICY NAME       ACTION   SCOPE
> ambient-authz   notification-l4   Allow    WorkloadSelector
>
> NAME              AGE
> notification-l4   12m
> notification-l7   9m
> ```
>
> Two lists that deliberately do not match. ztunnel holds only `notification-l4` — the L7 policy lives on the waypoint instead, and after [Part 3](./course-03-waypoints-and-l7-policy.md) that is correct rather than a problem. The useful reading is the *difference*: a policy in `kubectl get` and in neither component's list is a policy nothing will ever enforce.

For the waypoint's half, the command is the familiar one:

```sh
istioctl proxy-config listener deploy/waypoint -n ambient-authz -o json | grep -i rbac | head
```

So the diagnostic procedure for "my ambient policy does nothing" is three questions in order:

```text
   1. is it in kubectl get?               no  → it was never created
   2. is it in ztunnel-config policy,
      or on the waypoint's RBAC filter?   no  → nothing enforces it
                                                → L7 rule with no waypoint, or
                                                  wrong attachment form
   3. does the rule match the traffic?    no  → an ordinary policy bug
```

Step 2 is the one that does not exist in sidecar mode, and it is where most ambient surprises are resolved.

The traps here are all the same shape: a policy that applies cleanly and is enforced by nobody.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **An L7 rule in an ambient namespace with no waypoint** — accepted, listed, silently ignored. Check for a waypoint before trusting any method, path, header or JWT rule.
>
> **Using `selector` where `targetRefs` is needed** — L7 policy attaches to the waypoint in front of a service, not to pods.
>
> **Deploying a waypoint without enrolling the namespace or service** — the pod runs, the `Gateway` reports `PROGRAMMED: True`, and no traffic goes through it.
>
> **Expecting `403` from an L4 denial** — ztunnel refuses the connection, so the caller sees a connection error (`000` from `curl`), not a status code.
>
> **Assuming identity needs a waypoint** — it does not. ztunnel does mTLS over HBONE, so `principals` and `namespaces` work at L4.
>
> **Reaching for `-c istio-proxy` or `proxy-config` on an application pod** — there is no sidecar. Use `ztunnel-config`.
>
> **Assuming a `DENY` at L7 covers an L4 path** — a request that never reaches the waypoint is never evaluated by it. Put the connection-level half of a requirement in an L4 policy.
>
> **Removing a waypoint and forgetting its policies** — the L7 objects stay, stop being enforced, and still look active in `kubectl get`.

## What carries across unchanged

Most of this course applies to ambient mode without modification. Being explicit about which parts saves re-learning them:

| From | Still true in ambient mode |
| --- | --- |
| [010-01](../../section-010/module-01/course.md) Identity | identical — same SPIFFE URI, same service-account origin, same 24h rotation |
| [010-02](../../section-010/module-02/course.md) `PeerAuthentication` | applies; ztunnel does the mTLS. `STRICT` is effectively the ambient default between enrolled workloads |
| [010-03](../../section-010/module-03/course.md) Migration | the *procedure* carries; enrolment needs no pod restart, which removes its most disruptive step |
| [020-01](../../section-020/module-01/course.md) Policy structure | identical — `selector`, `action`, `rules`, and `ALLOW` creating default-deny |
| [020-02](../../section-020/module-02/course.md) Evaluation order | identical — `CUSTOM` → `DENY` → `ALLOW`, terminal on a match, at whichever component evaluates |
| [030](../../section-030/README.md) JWT | the objects are the same, and **all of it requires a waypoint** |
| [040](../../section-040/README.md) Edge TLS | unchanged; ingress gateways are unaffected by the dataplane mode behind them |
| [050](../../section-050/README.md) Gateway source IP | unchanged, and `ipBlocks` is available at L4 in-mesh too |

The one genuinely new thing to learn is the L4/L7 split and its attachment rules. Everything else is knowledge you already have, applied at a different enforcement point.

## The habit to take away

Before writing an ambient policy, decide which layer it belongs to:

```text
   does every field mention only identity, namespace, IP or port?
        │
       yes ──▶  ztunnel handles it. selector attachment. Nothing else needed.
        │
       no  ──▶  it mentions a method, path, host, header or token claim
                → it needs a waypoint
                → targetRefs attachment
                → deploy the waypoint AND enrol the traffic, or the rule is decoration
```

That question takes five seconds and prevents the module's entire pitfall list. It is also the useful summary of what ambient mode is: L4 security everywhere by default, L7 capability where you ask for it and pay for it — with the accepted-but-unenforced policy as the price of getting the question wrong.

> *Ask which layer a rule needs before writing it: identity, namespace, IP and port are free at L4, and everything else requires a waypoint that exists **and** receives the traffic.*

## Reference

- [`istioctl ztunnel-config`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-ztunnel-config) — the `workload`, `policy` and `certificate` subcommands used here.
- [Ambient L4 policy](https://istio.io/latest/docs/ambient/usage/l4-policy/) and [L7 features](https://istio.io/latest/docs/ambient/usage/l7-features/) — the authoritative statement of the split.
- [Ambient mode troubleshooting](https://istio.io/latest/docs/ambient/usage/troubleshooting/) — Istio's own guidance when a policy or a waypoint is not behaving.
