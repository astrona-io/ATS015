---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, a fellow astronaut has locked down the planet `starfleet` with least-privilege guest lists. Nobody can call a ship they should not call. But the bridge page no longer shows its reviews, and you have been asked to repair it without opening any shortcut.

The planet `starfleet` holds the Starfleet. Each ship runs under its own service account:

| Ship (Deployment) | Service account | Serves |
| --- | --- | --- |
| `bridge-v1` | `starfleet-bridge` | the page `/productpage` on port `9080`; it calls `cargo` and `scout` |
| `cargo-v1` | `starfleet-cargo` | `/details/0` on port `9080` |
| `scout-v1`, `scout-v2`, `scout-v3` | `starfleet-scout` | `/reviews/0` on port `9080`; v2 and v3 call `navcom` for star ratings |
| `navcom-v1` | `starfleet-navcom` | `/ratings/0` on port `9080` |
| `shuttle` | `shuttle` | a client pod with `curl`; send your test signals from here |

Istio 1.30.5 is installed, every pod in `starfleet` has its sidecar, and a `PeerAuthentication` named `default` puts the planet in **`STRICT`** mTLS. These `AuthorizationPolicy` objects already exist in `starfleet`:

* `allow-nothing` (`spec: {}`): the empty guest list for the whole planet. **It is correct.**
* `bridge-allow-get`: any caller may `GET` the bridge. **It is correct.**
* `cargo-allow-bridge`: only the bridge may `GET` cargo. **It is correct.**
* `scout-allow-bridge`: only the bridge may `GET` the scouts.
* `navcom-allow-scout`: only the scouts may `GET` navcom.

Something in the last two is wrong. Fix the problem so that:

1.  Every one of 12 loads of `http://bridge:9080/productpage` from the `shuttle` pod shows the reviews, with no text `currently unavailable` on the page.
2.  At least one of those loads shows star ratings (the HTML contains `glyphicon-star`). Only scout v2 and v3 show stars, and they get them from `navcom`.
3.  `scout-allow-bridge` selects the pods with `app: scout` and allows exactly one caller: the bridge's identity, written as a principal.
4.  `navcom-allow-scout` selects the pods with `app: navcom` and allows exactly one caller: the scouts' identity, written as a principal. The `navcom-v1` proxy must hold this policy.
5.  From the `shuttle` pod, `GET http://bridge:9080/productpage` returns `200`, and `GET` to `http://cargo:9080/details/0`, `http://scout:9080/reviews/0` and `http://navcom:9080/ratings/0` each return `403`.
6.  `allow-nothing` stays in place with an empty `spec`. No policy in `starfleet` may use `rules: [{}]` or a `namespaces` rule for these two lists.
7.  Leave the Deployments, their service accounts, the Services and the `PeerAuthentication` unchanged. Do not add or remove workloads.

A principal is written as `<trust domain>/ns/<namespace>/sa/<service account>`, without `spiffe://`. The trust domain is `cluster.local`.

The grader reads the policies, checks the `navcom-v1` proxy's listener with `istioctl proxy-config`, and sends live signals from the `shuttle` pod, so the fix has to work, not merely exist.
