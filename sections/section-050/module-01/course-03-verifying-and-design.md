# Part 3 — Verifying, and where address rules fit

> Prerequisite: [Part 2 — `X-Forwarded-For` and trusted proxies](./course-02-trusting-x-forwarded-for.md). Next: [the module landing page](./course.md), then [Section 060 — Authorization In Ambient Mode](../../section-060/README.md).

An address rule can be wrong in three places — the policy, the topology setting, and your assumption about what address arrives — and only one of them is visible in the object you wrote. This part is how to check all three, and then what source IP is actually worth as a control.

## Three things to read back

> [!TIP]
> **Try it — read back the policy, the topology setting and the decision**
>
> ```sh
> kubectl -n istio-system get authorizationpolicy
> kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' | grep -A2 gatewayTopology
> kubectl -n istio-system logs deploy/istio-ingressgateway --tail=10 | grep -E ' 403 | 200 '
> ```
>
> Expect something like:
>
> ```text
> NAME                AGE
> gateway-ip-deny     4m
> gatewayTopology:
>   numTrustedProxies: 1
> [2026-09-27T09:41:02.114Z] "GET /book HTTP/1.1" 403 - ... "10.1.2.3" "curl/8.4.0" ...
> ```
>
> Three different questions, three different sources. The first says which policies exist on the gateway — including any you forgot about, which on a shared gateway is a real possibility. The second confirms the topology setting survived the last `istioctl install`; an empty result means it is unset and `remoteIpBlocks` is not trustworthy. The third shows the decision **and the addresses together**, which is the only place they appear side by side.

The access log is the one to reach for first when a rule behaves unexpectedly, because it answers the question the policy cannot: *what address did the gateway actually see?* Comparing that against your CIDR settles in one line what reading YAML can take an afternoon to guess at.

The full ordering, when a gateway rule does not do what you expect:

```text
   1. does the policy exist and select the gateway?      kubectl get, and the labels
   2. is numTrustedProxies what the topology requires?   the istio ConfigMap
   3. what address did the gateway see?                  the access log
   4. does that address fall in the CIDR you wrote?      arithmetic
```

Steps 3 and 4 catch most of it. Step 1 catches the rest.

Address-based rules go wrong in a small number of specific ways, and two of them are security holes rather than outages.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **`ipBlocks` behind a load balancer** — every request appears to come from the load balancer, so the rule matches everything or nothing.
>
> **`remoteIpBlocks` without `numTrustedProxies`** — the header is client-controlled and the rule is bypassable. This is a vulnerability, not a cosmetic issue.
>
> **A `numTrustedProxies` that does not match the real topology** — too low trusts a spoofed value, too high reads an address that is not there.
>
> **The policy in the application namespace** — it must be where the gateway pod runs, and its `selector` must match the gateway's labels.
>
> **A selector that misses a second gateway** — `istio: ingressgateway` is the `demo` profile's label; a Gateway API or custom gateway carries different ones, and a rule that selects nothing blocks nothing.
>
> **An `ALLOW` on a shared gateway with no `hosts` narrowing** — it closes every hostname that gateway serves, not just yours.
>
> **Drawing conclusions from a `port-forward` test** — the source address is from inside the cluster. Read the access log rather than assuming.
>
> **Expecting a connection failure** — a gateway-scoped denial is an ordinary `403` with a body. The request was accepted, parsed, and refused.
>
> **Forgetting the topology setting after a reinstall** — `numTrustedProxies` is `meshConfig`, so an `istioctl install` without it silently reverts to the default.

## What an address is worth

Addresses are a coarse control, and being precise about their limits decides where they belong in a design.

**They are good at reducing exposure.** Restricting an admin path to an office range, blocking a known-abusive network, limiting a partner integration to that partner's published egress addresses. Each one shrinks the population that can even attempt a request, which is worth having regardless of what else is in place.

**They are weak as identity.** Addresses are shared behind NAT, reassigned by DHCP and cloud providers, borrowed through VPNs and proxies, and — in the `remoteIpBlocks` case — carried in a header that only a correct `numTrustedProxies` makes trustworthy. "This request came from 198.51.100.7" supports "it came from that office network" and does not support "it came from Alice".

Set against the other controls in this course:

| Control | Establishes | Strength | Where |
| --- | --- | --- | --- |
| source IP | the network it came from | weak, coarse | gateway, [this module] |
| client certificate | the calling system | strong | edge, [section 040](../../section-040/module-02/course.md) |
| JWT | the end user, plus roles | strong, expiring | edge or workload, [section 030](../../section-030/README.md) |
| mesh identity | the calling workload | strong | in-mesh, [section 020](../../section-020/README.md) |

Where the requirement is really "only this client", a client certificate or a JWT is the control that answers it. Source IP narrows who can attempt the request; it should rarely be the only thing between the internet and something that matters.

**They compose well, which is where they earn their place.** The common shape is one broad rule allowing normal traffic from anywhere, plus a narrow restriction on the one path that needs it:

```yaml
  action: ALLOW
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
      from:
        - source:
            remoteIpBlocks: ["203.0.113.0/24"]
```

with an authentication requirement layered on top, so that reaching `/admin` needs both the right network *and* the right credentials. Neither control is sufficient; together they are a meaningful barrier, and the address half is the one that costs nothing per request.

> *The access log is the only place the decision and the address appear together — and source IP narrows who can attempt a request, never who they are.*

## Reference

- [Ingress gateway authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-ingress/) — Istio's task, covering both source fields and the topology setting.
- [Configuring gateway network topology](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/) — `numTrustedProxies` and how to reason about your own chain.
- [Istio access logging](https://istio.io/latest/docs/tasks/observability/logs/access-log/) — enabling and reading the log this part depends on.
