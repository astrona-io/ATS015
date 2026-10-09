---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The `starfleet` namespace runs in ambient mode, and any workload can reach any other. Before the next patrol, the platform team wants two backends locked down, with rules that work today, without a waypoint.

The cluster runs Istio 1.30.5 in **ambient mode**: `istiod`, `istio-cni` and the `ztunnel` DaemonSet, and **no sidecars anywhere**. Namespace `starfleet` carries the label `istio.io/dataplane-mode=ambient`, so every pod is already in the mesh. Each workload runs as its own service account:

| Workload | Service account | Notes |
| --- | --- | --- |
| `bridge` | `starfleet-bridge` | web frontend; its API at `http://bridge:9080/api/v1/products/0` calls `cargo` |
| `cargo` | `starfleet-cargo` | backend for item details, Service on port `9080` |
| `scout` v1, v2, v3 | `starfleet-scout` | v2 and v3 call `navcom` for star ratings |
| `navcom` | `starfleet-navcom` | backend for star ratings, Service on port `9080` |
| `shuttle` | `shuttle` | your client pod with `curl` |

No `AuthorizationPolicy` and no waypoint exist.

In namespace `starfleet`:

1.  Create an `AuthorizationPolicy` named **`cargo-l4`** so that `cargo` accepts connections **only** from the `starfleet-bridge` identity.
2.  Create an `AuthorizationPolicy` named **`navcom-l4`** so that `navcom` accepts connections **only** from the `starfleet-scout` identity.
3.  Both policies must be enforced by ztunnel alone: attach them with a label `selector` on the `app` label, and use only L4 fields. No methods, paths, hosts, request principals or request conditions.
4.  Do **not** create a waypoint, and do not add the `istio.io/use-waypoint` label.

The result must be:

| From | Request | Expected |
| --- | --- | --- |
| `shuttle` | `http://cargo:9080/details/0` | connection closed (`curl` shows `000`) |
| `shuttle` | `http://navcom:9080/ratings/0` | connection closed (`000`) |
| `shuttle` | `http://bridge:9080/api/v1/products/0` | `200` (the bridge still reaches `cargo`) |
| `shuttle` | `http://scout:9080/reviews/0` | `200`, and the v2 and v3 answers still carry star ratings |

Constraints:

* Do not add sidecars or change the dataplane mode.
* Do not change any Deployment, Service or ServiceAccount.

The grader reads both policies, then sends live requests from the `shuttle` pod, so the rules have to work, not only exist.
