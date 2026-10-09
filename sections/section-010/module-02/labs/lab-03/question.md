---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

A teammate reports trouble. In the namespace `starfleet`, every request the shuttle sends to the probe fails with `503`. It started right after they added a `DestinationRule` for the probe, which they copied from another service to get `LEAST_REQUEST` load balancing.

The cluster has two namespaces:

* `starfleet`, with sidecar injection: `bridge`, `cargo`, `navcom` and `scout` v1/v2/v3, the client `shuttle`, and the `probe` v1/v2 behind a Service on port `8000`.
* `outpost`, **without** sidecar injection: the `drifter`, a pod with `curl` and no sidecar.

Istio 1.30.5 is installed. Two objects already exist in `starfleet`:

* A `PeerAuthentication` named `default` with `mode: STRICT`. **This policy is correct.**
* A `DestinationRule` named `probe`. Something in it is wrong.

Fix the problem so that:

1.  The shuttle gets `200` from `http://probe:8000/get`.
2.  The request uses mTLS: the probe's `/headers` answer to the shuttle shows `X-Forwarded-Client-Cert` with the shuttle's identity, `spiffe://cluster.local/ns/starfleet/sa/shuttle`.
3.  The drifter is still refused by the probe.
4.  The `DestinationRule` named `probe` still exists and still sets `loadBalancer.simple: LEAST_REQUEST`.
5.  The `PeerAuthentication` named `default` in `starfleet` is **left unchanged**, and you add no other `PeerAuthentication` anywhere.
6.  Leave the Deployments, Services and pod labels unchanged.

The grader reads the objects, then sends live requests from the shuttle and the drifter, so the fix has to work, not merely exist.
