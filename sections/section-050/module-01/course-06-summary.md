# Summary

Requests from outside the mesh carry no workload identity, so at the ingress gateway the useful fact is often the client's IP address. This module was about one question: which address did a request really come from, and can the gateway believe it?

## What you learned

A policy for the ingress gateway is an ordinary `AuthorizationPolicy`. It must live in the gateway's namespace and select the gateway pod's labels, because a `selector` only looks at pods in the policy's own namespace. In this playground that means `istio-ingress` and `istio: ingress`; an `istioctl` install uses `istio-system` and `istio: ingressgateway`. A policy in the app's namespace is accepted and applies to nothing.

A denial at the gateway is a normal `403`, and the request never enters the mesh. Pods already inside the mesh never pass through the gateway, so gateway rules do not protect them.

Istio has two address fields, and they read different addresses. `ipBlocks` matches the connection peer: whoever opened the connection to the gateway. Behind a load balancer, a content delivery network (CDN) or a port forward, that is the proxy, never the client. `remoteIpBlocks` matches the client address that the gateway takes from the `X-Forwarded-For` header.

That header is only as trustworthy as the `numTrustedProxies` setting. Each proxy adds the address it received the request from to the end of the list, and a client can write the first entries itself. `numTrustedProxies` says how many proxies you run, and the gateway counts that many entries from the right. Too low, and the gateway sees a proxy. Too high, and a client can fake its address. The gateway reads the setting when it starts, so it needs a restart, and Envoy shows the value in its listener as `xffNumTrustedHops`.

On a shared gateway, address rules work best as `DENY` policies. A block-list is a `DENY` with `remoteIpBlocks`. "Only this network may reach this path" is a `DENY` on the path with `notRemoteIpBlocks`, with `to` and `from` in the same rule. An `ALLOW` for the same idea denies every other request on the gateway, on every host.

When a rule surprises you, the gateway's access log is the place to look: it shows the decision, the matching policy and the client address on one line. An address, though, only tells you the network, never the person. Use it as a cheap first layer, with a real identity check behind it. The key facts to remember are these:

- A gateway policy lives in the gateway's namespace and selects the gateway pod's labels.
- `ipBlocks` reads the connection; `remoteIpBlocks` reads `X-Forwarded-For` through `numTrustedProxies`.
- The real key is `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies`, or the `proxy.istio.io/config` annotation on one gateway; a key directly under `meshConfig.gatewayTopology` is ignored.
- Prove a rule with one request that must pass and one that must be denied.

In short: find out which address the gateway really sees before you write a range.

<!-- astrona:playground:destroy -->
