# Authorization At The Edge

Inside the mesh, a policy can match on the identity the mesh gave each workload. At the edge that identity does not exist: the caller is on the internet, has no service account, and may show no certificate. What you often have instead is an address.

One module. It applies `AuthorizationPolicy` to the ingress gateway rather than to a workload, and spends its time on the difference that decides whether such a rule works or only looks like it does: `ipBlocks` matches the connection peer, `remoteIpBlocks` matches the client named in `X-Forwarded-For`, and behind a load balancer only one of them is ever right.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- Writing an `AuthorizationPolicy` that guards the ingress gateway, in the gateway's own namespace and with the gateway pod's labels.
- `ipBlocks`: the address of whoever opened the connection. Behind a load balancer, or a port forward, that is the relay, not the client.
- `remoteIpBlocks`: the client address the gateway reads from the `X-Forwarded-For` header.
- `numTrustedProxies`: how many relays the gateway trusts. Set it with `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies` or the gateway's `proxy.istio.io/config` annotation, and prove it with `xffNumTrustedHops` in the gateway's listener. Too low and the gate sees a relay; too high and a client can fake its address.
- That a refusal at the gate is an ordinary `403`, and that the refused signal never reaches the app.
- Opening one path to one network with a `DENY` rule and `notRemoteIpBlocks`, without closing the rest of the gate.
- Reading the gateway's access log to see the decision and the client address side by side.
- Where address rules help, and where a client certificate or a token is the control you really need.

---

<!-- astrona:playground -->