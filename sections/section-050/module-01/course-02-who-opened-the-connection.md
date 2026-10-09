# Match The Connection's Source With `ipBlocks`

When you want to keep a network out of the gateway, or let only one network in, you need a rule that matches the client's address. `AuthorizationPolicy` has two fields for that. The first one, `ipBlocks`, sounds like "the client's address", but it is not. It matches whoever opened the network connection to the gateway, and behind any proxy that is the proxy.

This matters because almost every real gateway has a proxy in front of it. A rule on the wrong address either blocks everyone or protects nothing, and both look fine in the YAML. This chapter shows the difference on your own playground, where a proxy already sits in front of the gateway.

## The connection peer

Every request reaches the gateway over a network connection, a TCP connection. The machine on the other end of that connection is the **connection peer**. `ipBlocks` matches the peer's address, and nothing else.

In a real cluster, outside requests rarely reach the gateway directly. A cloud load balancer, a content delivery network (CDN) or another proxy usually sits in front. Each one receives the request and forwards it over a new connection of its own:

```text
   real client          proxy (load balancer)       gateway
   198.51.100.7  ─────▶  203.0.113.4  ─────────────▶  sees the peer 203.0.113.4
                                                      ipBlocks matches THIS
```

So behind a proxy, `ipBlocks` sees the proxy, for every client, every time. An allow-list of your office range then matches nothing, and the gateway denies everyone. An allow-list of the proxy's range is worse: it matches everyone who comes through the proxy, so it looks like it works and protects nothing.

Your playground has such a proxy too. The port forward that `astrona run` keeps open carries your request into the cluster. It then opens a new connection to the gateway from inside the gateway pod. To see what the gateway makes of that, send one request and read the gateway's access log:

<!-- astrona:playground:renew -->

```sh
gate_status /productpage
gate_log
```

```text
200
[2026-10-09T11:04:53.897Z] "GET /productpage HTTP/1.1" 200 - via_upstream - "-" 0 15064 977 976 "10.244.0.6" "curl/8.7.1" "1b3b1ba4-6b5a-4ae0-b4ba-2125582363f9" "starfleet.example.com" "10.244.0.12:9080" outbound|9080||bridge.starfleet.svc.cluster.local 10.244.0.6:34838 127.0.0.1:80 127.0.0.1:38530 - -
```

Near the end of the line, just before the two dashes, are two addresses. The first is the gateway's own address (`127.0.0.1:80`), and the second is the peer's address (`127.0.0.1:38530`). The peer is `127.0.0.1`: the tunnel, not your laptop.

The quoted `"10.244.0.6"` earlier on the line is the `X-Forwarded-For` header. The gateway wrote it itself: it is the gateway pod's own address. This is the habit the whole module rests on: **before you write an address rule, find out which address the gateway really sees.**

## An allow-list on the peer

With that habit in mind, try the allow-list that many people write first: "only requests from the cluster's private network, `10.0.0.0/8`, may pass". Save this as `authorizationpolicy-gateway-ip-allow.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-allow
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: ALLOW
  rules:
  - from:
    - source:
        ipBlocks: ["10.0.0.0/8"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-ip-allow.yaml
```

Wait about a minute, so the gateway gets its new configuration. Then check the result:

```sh
gate_status /productpage
gate_status /api/v1/products
```

```text
403
403
```

Both requests are denied. The peer is `127.0.0.1`, which is not in `10.0.0.0/8`. And because this is an `ALLOW` policy, every request that matches none of its rules is denied, on every host and path the gateway serves. One wrong range closed the whole gateway.

The fix is to change only the range, to the peer you found in the access log. Save this as `authorizationpolicy-gateway-ip-allow.yaml` again:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-allow
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: ALLOW
  rules:
  - from:
    - source:
        ipBlocks: ["127.0.0.1/32"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-ip-allow.yaml
```

Wait about a minute again, then check the result. This time the second request carries a made-up client address in the `X-Forwarded-For` header. Proxies use that header to pass on the client's address:

```sh
gate_status /productpage
gate_status /productpage 192.168.5.5
```

```text
200
200
```

Both requests pass. The first proves that the rule now matches the peer. The second proves something just as important: `ipBlocks` never reads the header. Whatever address the request claims, `ipBlocks` only looks at the connection.

Remove the policy before you go on:

```sh
kubectl delete -f authorizationpolicy-gateway-ip-allow.yaml
```

## When `ipBlocks` is the right field

None of this makes `ipBlocks` a bad field; it just answers a narrow question. It is the right choice when clients connect to the gateway **directly**, with no proxy in between. For example, a gateway that is only reachable inside a private company network sees the callers' own addresses. It is also right when you really mean the proxy: "only requests that came through our own load balancer may pass".

So you now know that `ipBlocks` matches whoever opened the connection to the gateway. Behind any proxy, that is the proxy, never the client, and the last address on the access log line tells you which one it is. The open question is how to reach the real client behind a proxy. That needs the second field, `remoteIpBlocks`, which reads the client's address from the `X-Forwarded-For` header. It is only safe once the gateway knows how many proxies to trust.

## Common pitfalls

> [!WARNING]
> - **`ipBlocks` behind a load balancer.** Every request comes from the load balancer, so the rule matches everyone or no one.
> - **Writing a range before reading the access log.** The last address on the gateway's log line is the peer. Check it first; it often is not what you expect.
> - **Testing through a port forward and trusting the result.** The tunnel ends inside the gateway pod, so the peer is `127.0.0.1`.
> - **An `ALLOW` with the wrong range.** One `ALLOW` policy on the gateway denies every request its rules do not match, on every host. A wrong range closes the whole gateway.
