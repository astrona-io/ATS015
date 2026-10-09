---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The platform team has made mTLS (mutual TLS, where both sides present a certificate) required across the whole mesh. Since then, the drifter, a client pod without a sidecar proxy, gets no answer from any workload. It only needs one service: the probe. Open the probe for the drifter, and nothing else.

The cluster has two namespaces:

* `starfleet`, with sidecar injection: `bridge`, `cargo`, `navcom` and `scout` v1/v2/v3 on port `9080`, the client `shuttle`, and the `probe` v1/v2. The `probe` Service listens on port `8000` and sends requests on to container port `8080` on the pods. The probe pods carry the label `app: probe`.
* `outpost`, **without** sidecar injection: the `drifter`, a pod with `curl` and no sidecar.

Istio 1.30.5 is installed. A `PeerAuthentication` named `default` in `istio-system` sets the whole mesh to `STRICT`.

Produce this end state:

1.  A `PeerAuthentication` named `probe` in `starfleet` selects the probe pods. The probe as a whole stays `STRICT`, and only the port that receives the drifter's requests accepts plain text, using `portLevelMtls`.
2.  The drifter gets `200` from `http://probe.starfleet:8000/get`.
3.  The drifter is still refused by every other workload, for example `http://scout.starfleet:9080/reviews/0` and `http://navcom.starfleet:9080/ratings/0`.
4.  The shuttle still reaches the probe over mTLS: the probe's `/headers` answer to the shuttle shows the shuttle's identity, `spiffe://cluster.local/ns/starfleet/sa/shuttle`.

Constraints:

* Leave the mesh-wide `PeerAuthentication` in `istio-system` unchanged, and add no other policy there.
* Do not create a namespace-wide `PeerAuthentication` (one without a `selector`) in `starfleet`.
* Do not create a `DestinationRule`.
* Leave the Deployments, Services and pod labels unchanged. Do not add a sidecar to the drifter.

The grader reads your policy, then sends live requests from the drifter and the shuttle, so the result has to work, not merely exist.
