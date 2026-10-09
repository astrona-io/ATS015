---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

Astronaut, a fellow astronaut reports trouble. The `drifter` is an old ship on the planet `outpost`. It has no sidecar and must never get one. It needs to reach the `probe` on the planet `starfleet`, but every signal it sends there ends in a connection reset (`000`, curl exit code 56).

The cluster runs Istio 1.30.5. Two planets (namespaces) exist:

* **`starfleet`** has sidecar injection switched on. It runs the Starfleet (`bridge`, `cargo`, `scout` v1 to v3, `navcom`), the `shuttle` client and `probe` v1 and v2. The `probe` Service listens on port `8000` and sends signals on to the container port `8080`. Every probe pod carries the label `app: probe`.
* **`outpost`** has no sidecar injection. It runs the `drifter`, a client pod with `curl` and no sidecar.

Two `PeerAuthentication` objects already exist in `starfleet`:

* `default`: the whole planet is `STRICT`. **This policy is correct.**
* `probe`: meant to keep the probe `STRICT` but let plain signals in on one port. Something in it is wrong.

Fix the problem so that:

1.  The drifter gets `200` from `http://probe.starfleet:8000/get`.
2.  The drifter is still refused by `cargo` (`http://cargo.starfleet:9080/details/0`): every ship except the probe stays `STRICT`.
3.  The policy that selects `app: probe` keeps the workload mode `STRICT`, and opens only the probe's port to plain signals.
4.  The `shuttle` still gets `200` from both `probe` and `cargo`.
5.  The `default` policy in `starfleet` stays `STRICT`, with no `selector`.
6.  The drifter stays outside the mesh: do not label `outpost` for injection and do not add a sidecar to the drifter.
7.  Leave the Deployments and Services unchanged.

The grader sends live signals from the `drifter` and the `shuttle`, so the fix has to work, not merely exist.
