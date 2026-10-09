---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

Astronaut, the planet `starfleet` runs in ambient mode, and any ship can signal any other. Mission control wants two ships locked down before the next patrol, with rules that work today, without a waypoint.

The cluster runs Istio 1.30.5 in **ambient mode**: `istiod`, `istio-cni` and the `ztunnel` DaemonSet, and **no sidecars anywhere**. Namespace `starfleet` carries the label `istio.io/dataplane-mode=ambient`, so every ship is already in the mesh. Each ship runs as its own service account:

| Ship | Service account | Notes |
| --- | --- | --- |
| `bridge` | `starfleet-bridge` | the flagship; its API at `http://bridge:9080/api/v1/products/0` signals `cargo` |
| `cargo` | `starfleet-cargo` | the supply ship, Service on port `9080` |
| `scout` v1, v2, v3 | `starfleet-scout` | v2 and v3 signal `navcom` for star ratings |
| `navcom` | `starfleet-navcom` | the navigation computer, Service on port `9080` |
| `shuttle` | `shuttle` | your client pod with `curl` |

No `AuthorizationPolicy` and no waypoint exist.

In namespace `starfleet`:

1.  Create an `AuthorizationPolicy` named **`cargo-l4`** so that `cargo` accepts connections **only** from the `starfleet-bridge` identity.
2.  Create an `AuthorizationPolicy` named **`navcom-l4`** so that `navcom` accepts connections **only** from the `starfleet-scout` identity.
3.  Both policies must be enforced by ztunnel alone: attach them with a label `selector` on the `app` label, and use only L4 fields. No methods, paths, hosts, request principals or request conditions.
4.  Do **not** create a waypoint, and do not add the `istio.io/use-waypoint` label.

The result must be:

| From | Signal | Expected |
| --- | --- | --- |
| `shuttle` | `http://cargo:9080/details/0` | connection closed (`curl` shows `000`) |
| `shuttle` | `http://navcom:9080/ratings/0` | connection closed (`000`) |
| `shuttle` | `http://bridge:9080/api/v1/products/0` | `200` (the bridge still reaches `cargo`) |
| `shuttle` | `http://scout:9080/reviews/0` | `200`, and the v2 and v3 answers still carry star ratings |

Constraints:

* Do not add sidecars or change the dataplane mode.
* Do not change any Deployment, Service or ServiceAccount.

The grader reads both policies, then sends live signals from the `shuttle` pod, so the rules have to work, not only exist.
