# Authorize By Source IP At The Ingress Gateway

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-050/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/module-01/playground
> astrona destroy ats-015-playground-050-01
> ```

Every authorization rule so far has been about traffic already inside the mesh, matched on identities the mesh itself issued. At the edge neither applies: the caller is on the internet, has no service account, and may have no certificate. What you often have instead is an address — an office range, a partner's egress network, a block of abusive clients.

Istio can match on that, with an `AuthorizationPolicy` that selects the ingress gateway. The trap is that there are two different source-address fields, they mean genuinely different things, and behind a load balancer only one of them is ever right.

## How this module is organised

1. **[Part 1 — Authorizing at the gateway, and the connection peer](./course-01-authorizing-at-the-gateway.md)** — where a gateway-scoped policy lives, what enforcing at the edge buys you, and what `ipBlocks` actually matches.
2. **[Part 2 — `X-Forwarded-For` and trusted proxies](./course-02-trusting-x-forwarded-for.md)** — how the header is built hop by hop, what `numTrustedProxies` pins, and why `remoteIpBlocks` without it is decoration.
3. **[Part 3 — Verifying, and where address rules fit](./course-03-verifying-and-design.md)** — reading back what is in force, the access log, the pitfalls, and what source IP is and is not good for.

## Learning objectives

After this module you can:

- Write an `AuthorizationPolicy` that selects the ingress gateway, in the correct namespace and with the right selector.
- Explain what enforcing at the gateway changes about where a denied request stops.
- Distinguish `ipBlocks` from `remoteIpBlocks`, and choose the right one for a given topology.
- Describe how `X-Forwarded-For` is built as a request crosses proxies, and which element each setting reads.
- Explain what `meshConfig.gatewayTopology.numTrustedProxies` pins and why a rule is spoofable without it.
- Predict what a client sees when a gateway-scoped policy denies it, and find the decision in the access log.
- Recognise why a `kubectl port-forward` makes source-IP rules behave unexpectedly.

## Before you start

You need `AuthorizationPolicy` from [section 020](../../section-020/README.md) — `selector`, `action`, `rules`, `ALLOW` creating default-deny, and `DENY` beating `ALLOW`. All of that applies unchanged here; only the workload being selected and the source fields are new.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile, including `istio-ingressgateway` in `istio-system`) and:

- **`gwauthz-demo`** — injected. `booking-service-v1` (serving `/book`) and `notification-service-v1`.
- A **`Gateway` and `VirtualService`** for `booking.ica.local` on port 80, applied at bootstrap. They are the target of this module's policies, not its subject.

No `AuthorizationPolicy` exists yet, and `numTrustedProxies` is unset.

**`kind` has no load balancer**, so you will reach the gateway through `kubectl port-forward`. That has a real consequence for this module — the source address a port-forward presents is not the one you might expect, which [Part 1](./course-01-authorizing-at-the-gateway.md) uses deliberately.
