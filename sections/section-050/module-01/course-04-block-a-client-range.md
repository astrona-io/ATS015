# Block A Client Range With `remoteIpBlocks`

A range of addresses keeps attacking the `starfleet` app, and you must stop it at the ingress gateway. There is a proxy in front of the gateway, so the connection only shows the proxy, never the attacker. A rule on the connection address would miss the attack completely.

This chapter uses the second address field, `remoteIpBlocks`, which reads the real client's address from the `X-Forwarded-For` header. You will write the rule, prove it with requests that must pass and must fail, and read the decision in the access log. You will also see why a block-list should be a `DENY` and not an `ALLOW`.

## The two address fields side by side

Both address fields sit in the `source` part of a rule. Both take address ranges written in CIDR form (Classless Inter-Domain Routing): an address plus how many leading bits must match, such as `192.168.0.0/16`. They differ only in which address they read:

| Field | Reads | Behind a proxy it sees |
| --- | --- | --- |
| `ipBlocks` | the connection peer | the proxy |
| `remoteIpBlocks` | the client address the gateway took from `X-Forwarded-For`, using `numTrustedProxies` | the real client, if the number is right |
| `notIpBlocks`, `notRemoteIpBlocks` | the same addresses, negated: "not in this range" | |

The connection peer is whoever opened the connection to the gateway. `numTrustedProxies` is the setting that tells the gateway how many proxies run in front of it, so it knows which entry of `X-Forwarded-For` to believe. That makes `remoteIpBlocks` only as good as `numTrustedProxies`. With no trusted proxies, the gateway ignores the header, and `remoteIpBlocks` sees the same peer as `ipBlocks`.

<!-- astrona:playground:renew -->

So before you write the rule, ask the gateway's listener whether it trusts one proxy:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops
```

```text
                            "xffNumTrustedHops": 1,
```

If this prints nothing, `numTrustedProxies` is not set. Set `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies: 1` on the `istiod` Helm release, restart the gateway with `kubectl rollout restart deployment/istio-ingress -n istio-ingress`, and check again.

## Deny the range at the gateway

With the gateway trusting one proxy, you can write the rule itself. The attacking range is `192.168.0.0/16`, and everyone else must still get through, on every host the gateway serves. Save this as `authorizationpolicy-gateway-ip-deny.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-deny
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - from:
    - source:
        remoteIpBlocks: ["192.168.0.0/16"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-ip-deny.yaml
```

Wait about a minute, so the gateway gets its new configuration. Then check the result with three requests: one from a normal client, one from the attacking range, and one with no header at all:

```sh
gate_status /productpage 10.1.2.3
gate_status /productpage 192.168.5.5
gate_status /productpage
```

```text
200
403
200
```

Only the request from `192.168.5.5` is denied. Two requests that differ only in one header get different answers, so the rule reads the client address, not the connection. The request with no header passes too. With no entry to read, the gateway falls back to the connection peer, `127.0.0.1`, which is not in the range.

The status codes tell you what happened, but not why. For that, print the last two lines of the gateway's access log, for the denied request and the one without a header:

```sh
gate_log 2
```

```text
[2026-10-09T11:11:48.721Z] "GET /productpage HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-ingress]-policy[gateway-ip-deny]-rule[0]] - "-" 0 19 0 - "192.168.5.5,10.244.0.18" "curl/8.7.1" "f69eb44a-82cb-4850-8db3-ba7891c5bd2c" "starfleet.example.com" "-" outbound|9080||bridge.starfleet.svc.cluster.local - 127.0.0.1:80 192.168.5.5:0 - -
[2026-10-09T11:11:48.734Z] "GET /productpage HTTP/1.1" 200 - via_upstream - "-" 0 15068 23 23 "10.244.0.18" "curl/8.7.1" "c03bbb5c-750a-9951-865c-b26274ed8e08" "starfleet.example.com" "10.244.0.12:9080" outbound|9080||bridge.starfleet.svc.cluster.local 10.244.0.18:48876 127.0.0.1:80 127.0.0.1:41648 - -
```

The denied line names the policy and the rule that matched, and ends with the client address the gateway decided on: `192.168.5.5:0`. The second line, for the request with no header, ends with the tunnel's address, `127.0.0.1`.

> [!TIP]
> When an address rule surprises you, read the gateway's access log first. It is the only place where the decision and the client address appear side by side on one line.

An attacker from `192.168.5.5` might try one more trick: put a harmless address in front, hoping the gateway reads the first entry. In this playground your `curl` acts as the trusted proxy, so the **last** entry is the one a proxy wrote. Send both orders:

```sh
gate_status /productpage "10.1.2.3, 192.168.5.5"
gate_status /productpage "192.168.5.5, 10.1.2.3"
```

```text
403
200
```

The first request is denied: the trusted last entry is `192.168.5.5`, and the forged `10.1.2.3` in front is ignored. The second passes, because its trusted entry is `10.1.2.3`. The gateway only ever reads the entry that `numTrustedProxies` points at.

## Why a block-list should be a `DENY`

The task was "deny this range, keep everything else". A `DENY` policy says exactly that: it denies the requests that match, and leaves every other request alone.

You could also write "allow everyone **not** in the range" as an `ALLOW` with `notRemoteIpBlocks`. On this one policy it gives the same answers. But the gateway is shared, and an `ALLOW` policy changes the rules for everyone. Once any `ALLOW` policy selects the gateway, every request that matches none of its rules is denied, on every host.

That makes an `ALLOW` fragile over time. Add a host or a path to its rule later, and you close the gateway for everything outside it. A `DENY` never closes anything it does not name. Keep the `ALLOW` shape for real allow-lists, and even then narrow the rule with `hosts` so you know which hosts you are closing.

Remove the policy before the lab:

```sh
kubectl delete -f authorizationpolicy-gateway-ip-deny.yaml
```

You now know that `remoteIpBlocks` matches the client address the gateway took from `X-Forwarded-For`, so it is only as trustworthy as `numTrustedProxies`. A block-list is a `DENY` with `remoteIpBlocks`, proved with one request that must pass and one that must fail. The opposite need, letting only one network reach a path, needs a little more thought on a shared gateway.

## Common pitfalls

> [!WARNING]
> - **`remoteIpBlocks` without `numTrustedProxies`.** The gateway ignores the header and the field sees the proxy. Check `xffNumTrustedHops` on the gateway first.
> - **`ipBlocks` for a client behind a proxy.** It reads the connection, never the header, so the attacking range is never matched.
> - **An `ALLOW` for a block-list.** On a shared gateway, an `ALLOW` decides for every host. A `DENY` only touches what it names.
> - **Testing only one address.** Always send one request that must pass and one that must be denied. A rule that denies everything also "blocks the range".

## Your mission: Block A Client Range At The Gateway

You can now block a client range at the ingress gateway by its real address, and prove that everyone else still gets through. Now prove it in a graded lab: a load balancer sits in front of the gateway, and you must deny `192.168.0.0/16` without closing anything else.

The lab runs its own small app, not the Starfleet: a `booking-service` behind the host `booking.ica.local`. Istio is installed there with `istioctl` and the `demo` profile, so its gateway runs in `istio-system` with the label `istio: ingressgateway`, and `numTrustedProxies` is already set to `1`. Read those values from the cluster before you write the policy.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-050-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-050-01
astrona start ats-015-playground-050-01
```
