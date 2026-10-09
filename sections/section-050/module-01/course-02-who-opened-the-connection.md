# Match The Connection's Source With `ipBlocks`

The first address field sounds like "the client's address". It is not. `ipBlocks` matches whoever opened the network connection to the gateway, and behind any proxy that is the proxy. This part shows the difference on your own playground, where a proxy already sits in front of the gateway.

## The connection peer

Every request reaches the gateway over a network connection, a TCP connection. The machine on the other end of that connection is the **connection peer**. `ipBlocks` matches the peer's address, and nothing else.

### A proxy in front of the gateway

In a real cluster, outside requests rarely reach the gateway directly. A cloud load balancer, a content delivery network (CDN) or another proxy usually sits in front. Each one receives the request and forwards it over a new connection of its own.

```text
   real client          proxy (load balancer)       gateway
   198.51.100.7  ─────▶  203.0.113.4  ─────────────▶  sees the peer 203.0.113.4
                                                      ipBlocks matches THIS
```

So behind a proxy, `ipBlocks` sees the proxy, for every client, every time. An allow-list of your office range then matches nothing, and the gateway denies everyone. An allow-list of the proxy's range matches everyone who comes through it, which is worse: it looks like it works and protects nothing.

### Your playground has a proxy too

The port forward that `astrona run` keeps open acts as such a proxy. It carries your request into the cluster and opens a new connection to the gateway from inside the gateway pod. Send one request and read the gateway's access log:

<!-- astrona:playground:renew -->

```sh
gate_status /productpage
gate_log
```

```text
200
[2026-10-09T11:04:53.897Z] "GET /productpage HTTP/1.1" 200 - via_upstream - "-" 0 15064 977 976 "10.244.0.6" "curl/8.7.1" "1b3b1ba4-6b5a-4ae0-b4ba-2125582363f9" "starfleet.example.com" "10.244.0.12:9080" outbound|9080||bridge.starfleet.svc.cluster.local 10.244.0.6:34838 127.0.0.1:80 127.0.0.1:38530 - -
```

Near the end of the line, just before the two dashes, are two addresses: the gateway's own address (`127.0.0.1:80`) and the peer's address (`127.0.0.1:38530`). The peer is `127.0.0.1`: the tunnel, not your laptop. The quoted `"10.244.0.6"` earlier on the line is the `X-Forwarded-For` header, which the gateway wrote itself: it is the gateway pod's own address. This is the habit the whole module rests on: **before you write an address rule, find out which address the gateway really sees.**

## An allow-list on the peer

Now write the allow-list that many people write first: "only requests from the cluster's private network, `10.0.0.0/8`, may pass".

### Allow a range the gateway never sees

Save this as `authorizationpolicy-gateway-ip-allow.yaml`:

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

Both are denied. The peer is `127.0.0.1`, which is not in `10.0.0.0/8`. And because this is an `ALLOW` policy, every request that matches none of its rules is denied, on every host and path the gateway serves. One wrong range closed the whole gateway.

### Allow the address the gateway really sees

Change only the range, to the peer you found in the access log. Save this as `authorizationpolicy-gateway-ip-allow.yaml` again:

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

Wait about a minute again. Then check the result. The second request carries a made-up client address in the `X-Forwarded-For` header, a header that proxies use to pass on the client's address:

```sh
gate_status /productpage
gate_status /productpage 192.168.5.5
```

```text
200
200
```

Both pass. The first proves the rule now matches the peer. The second proves something just as important: `ipBlocks` never reads the header. Whatever address the request claims, `ipBlocks` only looks at the connection.

### Clean up

Remove the policy before you go on:

```sh
kubectl delete -f authorizationpolicy-gateway-ip-allow.yaml
```

## When `ipBlocks` is the right field

`ipBlocks` is the right choice when clients connect to the gateway **directly**, with no proxy in between. For example, a gateway that is only reachable inside a private company network, where the callers' own addresses arrive at the gateway. It is also right when you really mean the proxy: "only requests that came through our own load balancer may pass".

When a proxy stands in front of the gateway and you mean the real client, you need the second field, `remoteIpBlocks`. It reads the client's address from the `X-Forwarded-For` header, and it is only safe once the gateway knows how many proxies to trust.

## Common pitfalls

> [!WARNING]
> - **`ipBlocks` behind a load balancer.** Every request comes from the load balancer, so the rule matches everyone or no one.
> - **Writing a range before reading the access log.** The last address on the gateway's log line is the peer. Check it first; it often is not what you expect.
> - **Testing through a port forward and trusting the result.** The tunnel ends inside the gateway pod, so the peer is `127.0.0.1`.
> - **An `ALLOW` with the wrong range.** One `ALLOW` policy on the gateway denies every request its rules do not match, on every host. A wrong range closes the whole gateway.

> *`ipBlocks` matches whoever opened the connection to the gateway. Behind any proxy, that is the proxy, never the client.*
