# Wrap-Up

You have controlled access at the ingress gateway by IP address, and you know which address each field reads. Before you move on, look back at what you learned, check yourself, and clean up the playground.

## What you learned

This module was about one question at the edge of the mesh: which address did this request really come from, and can the gateway believe it?

**From [Apply An AuthorizationPolicy To The Ingress Gateway](./course-01-guard-the-arrival-gate.md):**

- A policy for the ingress gateway is an ordinary `AuthorizationPolicy`. It must live in the gateway's namespace (`istio-ingress` here) and select the gateway pod's labels (`istio: ingress` for the Helm chart, `istio: ingressgateway` for an `istioctl` install).
- A policy in the app's namespace is accepted and applies to nothing, because a `selector` only looks at pods in the policy's own namespace.
- A denial at the gateway is a normal `403`. The gateway's access log names the policy in `rbac_access_denied_matched_policy[...]`.
- A request denied at the gateway never enters the mesh. Pods already inside never pass through the gateway, so gateway rules do not apply to them.
- One gateway serves many hosts. Name `hosts` in the rule so the rule only applies to your own.

**From [Match The Connection's Source With `ipBlocks`](./course-02-who-opened-the-connection.md):**

- `ipBlocks` matches the connection peer: whoever opened the connection to the gateway. Behind a load balancer, a content delivery network (CDN) or a port forward, that is the proxy.
- The last address on the gateway's access log line is the peer. Read it before you write a range.
- `ipBlocks` never reads `X-Forwarded-For`.
- One `ALLOW` policy with a wrong range closes the whole gateway.

**From [Set `numTrustedProxies` For `X-Forwarded-For`](./course-03-trust-the-right-number-of-relays.md):**

- Each proxy adds the address it received the request from to the end of `X-Forwarded-For`. A client can write the first entries itself.
- `numTrustedProxies` says how many proxies you run. The gateway counts that many entries from the right and treats that address as the client.
- Too low and the gateway sees a proxy. Too high and a client can fake its address.
- With Helm, set `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies` on `istiod`, or the `proxy.istio.io/config` annotation on one gateway, then restart the gateway.
- Prove it with `xffNumTrustedHops` in `istioctl proxy-config listener ... -o json`.

**From [Block A Client Range With `remoteIpBlocks`](./course-04-block-a-client-range.md):**

- `remoteIpBlocks` matches the client address the gateway took from `X-Forwarded-For`. It is only as good as `numTrustedProxies`.
- A block-list is a `DENY` with `remoteIpBlocks`. It denies the range and leaves everything else alone.
- Without a header, the gateway falls back to the connection peer.
- A forged entry in front of the trusted one is ignored.

**From [Allow One Path From One Network Only](./course-05-one-path-one-network.md):**

- "Only this network may reach this path" is a `DENY` for the path with `notRemoteIpBlocks`. `to` and `from` go in the same rule.
- An `ALLOW` for the same idea denies every other path on the gateway.
- Check in this order: the policy and its selector, the trusted proxies, the address in the access log, then the range.
- An address shows the network, never the person. Use it as a cheap first layer, with a real identity check behind it.

## Your labs

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Block A Client Range At The Gateway](./labs/lab-01/README.md) | Block A Client Range With `remoteIpBlocks` | deny a forwarded client range at the gateway without closing anything else |
| [Open One Path To One Network](./labs/lab-02/README.md) | Allow One Path From One Network Only | open one path to one network and keep the rest of the gateway open |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Your policy selects <code>istio: ingress</code> and lives in <code>starfleet</code>. Kubernetes accepted it. Does it apply to the gateway?</summary>

No. A `selector` only looks at pods in the policy's own namespace. The gateway pod runs in `istio-ingress`, so the policy must live there.
</details>

<details>
<summary>2. A load balancer stands in front of the gateway. You write an <code>ipBlocks</code> allow-list for your office range. What happens?</summary>

Every request is denied. `ipBlocks` sees the load balancer's address, which is not in the office range, and the `ALLOW` policy denies everything that matches none of its rules.
</details>

<details>
<summary>3. One load balancer, <code>numTrustedProxies: 1</code>. A request arrives with <code>X-Forwarded-For: 10.1.2.3, 192.168.5.5</code>. Which address does <code>remoteIpBlocks</code> match?</summary>

`192.168.5.5`, the last entry. The gateway counts one entry from the right. `10.1.2.3` was written by the client and is ignored.
</details>

<details>
<summary>4. Someone sets <code>numTrustedProxies: 2</code>, but only one load balancer runs. Why is that dangerous?</summary>

The gateway now counts past the load balancer's entry and believes an entry the client wrote. A client can send any address in front and pass a block-list.
</details>

<details>
<summary>5. You set <code>numTrustedProxies</code> and your <code>remoteIpBlocks</code> rule still matches nothing. What do you check?</summary>

First, `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops`. If it is missing, the key is in the wrong place (it belongs under `meshConfig.defaultConfig.gatewayTopology`) or the gateway was not restarted. Then read the client address in the gateway's access log.
</details>

<details>
<summary>6. "Only <code>203.0.113.0/24</code> may reach <code>/admin</code>." Why not an <code>ALLOW</code> with the path and the range?</summary>

Once an `ALLOW` policy selects the gateway, every request that matches none of its rules is denied. Every other path on the gateway would close. Write it as a `DENY` for `/admin` with `notRemoteIpBlocks: ["203.0.113.0/24"]`.
</details>

<details>
<summary>7. The gateway denies a request. Where can you see both the decision and the address it used?</summary>

In the gateway's access log: `kubectl logs -n istio-ingress deploy/istio-ingress`. The line shows `403`, the matching policy, and the client address at the end.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-050-01
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-050-01-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *At the gateway, `ipBlocks` sees whoever opened the connection, `remoteIpBlocks` sees the client the proxies reported, and `numTrustedProxies` decides how much of that report to believe.*
