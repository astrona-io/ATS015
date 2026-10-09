# Wrap-Up: Mission Debrief

Well flown, astronaut. You have guarded the arrival gate by address, and you know which address each field reads. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about one question at the edge of the solar system: which address did this signal really come from, and can the gate believe it?

**From [Guard The Arrival Gate](./course-01-guard-the-arrival-gate.md):**

- A policy for the ingress gateway is an ordinary `AuthorizationPolicy`. It must live on the gateway's planet (`istio-ingress` here) and select the gateway pod's labels (`istio: ingress` for the Helm chart, `istio: ingressgateway` for an `istioctl` install).
- A policy on the app's planet is accepted and guards nothing, because a `selector` only looks at pods in the policy's own namespace.
- A refusal at the gate is a normal `403`. The gate's flight log names the policy in `rbac_access_denied_matched_policy[...]`.
- A signal refused at the gate never enters the mesh. Ships already inside never pass the gate, so gate rules do not guard them.
- One gateway serves many hosts. Name `hosts` in the rule so you only guard your own.

**From [Who Opened The Connection: `ipBlocks`](./course-02-who-opened-the-connection.md):**

- `ipBlocks` matches the connection peer: whoever opened the connection to the gate. Behind a load balancer, a CDN or a port forward, that is the relay.
- The last address on the gate's flight log line is the peer. Read it before you write a range.
- `ipBlocks` never reads `X-Forwarded-For`.
- One `ALLOW` policy with a wrong range closes the whole gate.

**From [Trust The Right Number Of Relays](./course-03-trust-the-right-number-of-relays.md):**

- Each relay adds the address it received the signal from to the end of `X-Forwarded-For`. A client can write the first entries itself.
- `numTrustedProxies` says how many relays you run. The gateway counts that many entries from the right and treats that address as the client.
- Too low and the gate sees a relay. Too high and a client can fake its address.
- With Helm, set `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies` on `istiod`, or the `proxy.istio.io/config` annotation on one gateway, then restart the gateway.
- Prove it with `xffNumTrustedHops` in `istioctl proxy-config listener ... -o json`.

**From [Block A Client Range With `remoteIpBlocks`](./course-04-block-a-client-range.md):**

- `remoteIpBlocks` matches the client address the gateway took from `X-Forwarded-For`. It is only as good as `numTrustedProxies`.
- A block-list is a `DENY` with `remoteIpBlocks`. It refuses the range and leaves everything else alone.
- Without a header, the gateway falls back to the connection peer.
- A forged entry in front of the trusted one is ignored.

**From [One Path, One Network](./course-05-one-path-one-network.md):**

- "Only this network may reach this path" is a `DENY` for the path with `notRemoteIpBlocks`. `to` and `from` go in the same rule.
- An `ALLOW` for the same idea refuses every other path on the gate.
- Check in this order: the policy and its selector, the trusted relays, the address in the flight log, then the range.
- An address shows the network, never the person. Use it as a cheap first layer, with a real identity check behind it.

## Your missions

You proved each skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Block A Client Range At The Gateway](./labs/lab-01/README.md) | Block A Client Range With `remoteIpBlocks` | refuse a forwarded client range at the gate without closing anything else |
| [Open One Path To One Network](./labs/lab-02/README.md) | One Path, One Network | open one path to one network and keep the rest of the gate open |

If you skipped one, go back to it now. Each mission is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Your policy selects <code>istio: ingress</code> and lives in <code>starfleet</code>. Kubernetes accepted it. Does it guard the gate?</summary>

No. A `selector` only looks at pods in the policy's own namespace. The gateway pod runs in `istio-ingress`, so the policy must live there.
</details>

<details>
<summary>2. A load balancer stands in front of the gate. You write an <code>ipBlocks</code> allow-list for your office range. What happens?</summary>

Every signal is refused. `ipBlocks` sees the load balancer's address, which is not in the office range, and the `ALLOW` policy refuses everything that matches none of its rules.
</details>

<details>
<summary>3. One load balancer, <code>numTrustedProxies: 1</code>. A signal arrives with <code>X-Forwarded-For: 10.1.2.3, 192.168.5.5</code>. Which address does <code>remoteIpBlocks</code> match?</summary>

`192.168.5.5`, the last entry. The gateway counts one entry from the right. `10.1.2.3` was written by the client and is ignored.
</details>

<details>
<summary>4. Someone sets <code>numTrustedProxies: 2</code>, but only one load balancer runs. Why is that dangerous?</summary>

The gateway now counts past the load balancer's entry and believes an entry the client wrote. A client can send any address in front and pass a block-list.
</details>

<details>
<summary>5. You set <code>numTrustedProxies</code> and your <code>remoteIpBlocks</code> rule still matches nothing. What do you check?</summary>

First, `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops`. If it is missing, the key is in the wrong place (it belongs under `meshConfig.defaultConfig.gatewayTopology`) or the gateway was not restarted. Then read the client address in the gate's flight log.
</details>

<details>
<summary>6. "Only <code>203.0.113.0/24</code> may reach <code>/admin</code>." Why not an <code>ALLOW</code> with the path and the range?</summary>

Once an `ALLOW` policy selects the gateway, every signal that matches none of its rules is refused. Every other path on the gate would close. Write it as a `DENY` for `/admin` with `notRemoteIpBlocks: ["203.0.113.0/24"]`.
</details>

<details>
<summary>7. The gate refuses a signal. Where can you see both the decision and the address it used?</summary>

In the gate's flight log: `kubectl logs -n istio-ingress deploy/istio-ingress`. The line shows `403`, the matching policy, and the client address at the end.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-050-01
```

If `astrona list` also showed a mission, remove it the same way, for example:

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

> *At the gate, `ipBlocks` sees whoever opened the connection, `remoteIpBlocks` sees the client the relays reported, and `numTrustedProxies` decides how much of that report to believe.*
