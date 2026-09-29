# Part 2 — `X-Forwarded-For` and trusted proxies

> Prerequisite: [Part 1 — Authorizing at the gateway, and the connection peer](./course-01-authorizing-at-the-gateway.md). Next: [Part 3 — Verifying, and where address rules fit](./course-03-verifying-and-design.md).

`ipBlocks` sees the intermediary. The field that sees the real client reads a **header** instead of a socket — which makes it useful and, without one more setting, trivially forgeable. This part is that header, the setting, and the reasoning that connects them.

## How the header is built

`X-Forwarded-For` is an ordered list of addresses, appended to by each proxy that forwards the request:

```text
   real user          CDN               cloud LB            gateway
   198.51.100.7  ──▶  203.0.113.9  ──▶  192.0.2.50   ──▶    receives:
                                                             XFF: 198.51.100.7, 203.0.113.9
                                                             peer: 192.0.2.50

   each hop appends the address it RECEIVED the connection from,
   so the list reads left-to-right = furthest-to-nearest
```

The last hop's address is never in the header — it is the connection peer, which `ipBlocks` matches. So the two fields read adjacent positions in the same chain:

```text
   XFF:  198.51.100.7 , 203.0.113.9        peer: 192.0.2.50
         └─ the client   └─ the CDN              └─ the load balancer
            remoteIpBlocks                          ipBlocks
            (with numTrustedProxies = 2)
```

And now the problem. Anything in that list arrived as a header, and the first entry was appended by the **first proxy** — which took it from whatever the client sent. A client can send its own `X-Forwarded-For`, and proxies append rather than replace, so a forged value ends up at the front of the list exactly where a naive reader would look for the client.

```text
   attacker sends:  X-Forwarded-For: 10.1.2.3      (a lie)
        │
   CDN appends the real peer:  10.1.2.3, 198.51.100.7
        │
   gateway reading "the first element" believes 10.1.2.3
```

An allow-list built that way is decoration.

## `numTrustedProxies` pins where to look

The fix is telling Istio how many proxies are genuinely in front of the gateway:

```yaml
meshConfig:
  gatewayTopology:
    numTrustedProxies: 1
```

With a count `N`, the gateway skips `N` hops back from the end of the chain and treats the address it lands on as the client. Everything further left — including anything a client injected — is ignored.

```text
   chain as the gateway sees it:   [ forged? , client , proxy1 , proxy2 ] + peer
                                                  ▲
   numTrustedProxies: 2  ──────────────────────────┘  counts back 2 trusted hops
```

The count must match reality, and both errors are real:

- **too low** — you count back fewer hops than exist and land on an address a proxy or a client supplied. The rule becomes spoofable, which is the failure you were trying to prevent.
- **too high** — you count back past the start of the chain and read something that is not a client address at all. Legitimate traffic is denied, with no obvious cause.

So the number is a fact about your deployment topology, not a tuning knob: one load balancer is `1`, a CDN plus a load balancer is `2`. When the topology changes — a CDN added in front — the number has to change with it, and nothing in the cluster will remind you.

`numTrustedProxies` is an install-time `meshConfig` setting, so changing it goes through `istioctl install` and restarts the gateway. That makes it the one change in this module with a brief interruption attached, and worth getting right once rather than iterating on.

## `remoteIpBlocks` in use

With the topology pinned, `remoteIpBlocks` matches the address the gateway derived as the originating client:

```yaml
  action: DENY
  rules:
    - from:
        - source:
            remoteIpBlocks:
              - 192.168.0.0/16
```

> [!TIP]
> **Try it — deny a range by forwarded client address**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: gateway-ip-deny
>   namespace: istio-system
> spec:
>   selector:
>     matchLabels:
>       istio: ingressgateway
>   action: DENY
>   rules:
>     - from:
>         - source:
>             remoteIpBlocks:
>               - 192.168.0.0/16
> YAML
>
> istioctl install --set profile=demo \
>   --set meshConfig.gatewayTopology.numTrustedProxies=1 -y
> kubectl -n istio-system rollout status deploy/istio-ingressgateway
>
> kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
> sleep 2
> curl -s -o /dev/null -w 'xff 10.1.2.3:    %{http_code}\n' \
>   -H "Host: booking.ica.local" -H "X-Forwarded-For: 10.1.2.3" http://localhost:8080/book
> curl -s -o /dev/null -w 'xff 192.168.5.5: %{http_code}\n' \
>   -H "Host: booking.ica.local" -H "X-Forwarded-For: 192.168.5.5" http://localhost:8080/book
> ```
>
> Expect something like:
>
> ```text
> xff 10.1.2.3:    200
> xff 192.168.5.5: 403
> ```
>
> The `istioctl install` restarts the gateway, so the earlier port-forward dies and a new one is needed — that is why it is re-run here. Two identical requests differing only in a header, with different outcomes: the header is now what the rule reads.
>
> And notice what you just did to demonstrate it — you set `X-Forwarded-For` by hand, from a client. With `numTrustedProxies: 1` and the port-forward acting as the single trusted hop, that value is exactly where the gateway looks. In a real deployment the trusted hop is a load balancer you control, which is the entire difference between this being a demonstration and being a vulnerability.

## `DENY` is the right action here, usually

Note the example is a `DENY`. That is not incidental.

An `ALLOW` policy on a shared gateway closes it for *everything* that policy selects — every hostname the gateway serves, per [Part 1](./course-01-authorizing-at-the-gateway.md) — unless the rule also narrows by `hosts` or `paths`. A block-list expressed as `DENY` subtracts specific ranges and leaves everything else untouched, which is both what the requirement usually says and much harder to get catastrophically wrong.

When an allow-list genuinely is the requirement — an admin surface reachable only from the office — write it as an `ALLOW` *with* a `to.operation.paths` narrowing it to that surface, so the rest of the gateway is unaffected. The union semantics from [section 020](../../section-020/module-01/course-04-identity-union-and-debugging.md) still apply: a second, broader `ALLOW` elsewhere on the same gateway can reopen what you thought you had closed.

> *`remoteIpBlocks` reads a header, so it is only trustworthy once `numTrustedProxies` pins how many hops to count back — and that number is a fact about your topology, not a setting to tune.*

## Common pitfalls

> [!WARNING]
> **Trusting `X-Forwarded-For` by default.** It is a client-supplied header until the proxy is configured to know how many hops in front of it are trustworthy.
>
> **Writing an IP rule without setting the trusted-hop count.** The address you match is then whatever the caller claimed.
>
> **Assuming the load balancer preserves the client address.** Many do not, and the setting depends on how yours is deployed.
>
> **Using IP allow-lists as the only control.** Addresses are spoofable and change; identity is the durable thing to authorize on.

## Reference

- [Configuring gateway network topology](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/) — `numTrustedProxies`, `forwardClientCertDetails` and how the chain is interpreted.
- [AuthorizationPolicy `Source`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `remoteIpBlocks` and `notRemoteIpBlocks`.
- [RFC 7239 — Forwarded HTTP extension](https://datatracker.ietf.org/doc/html/rfc7239) — the standardised successor to `X-Forwarded-For`, and the semantics both share.
