---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

A fellow crew member has locked down the namespace `starfleet` with least-privilege `AuthorizationPolicy` objects. No workload can call a service it should not call. But the `bridge` page no longer shows its reviews, and you have been asked to repair it without opening any shortcut.

The namespace `starfleet` runs the Starfleet sample app. Each workload runs under its own service account:

| Workload (Deployment) | Service account | Serves |
| --- | --- | --- |
| `bridge-v1` | `starfleet-bridge` | the page `/productpage` on port `9080`; it calls `cargo` and `scout` |
| `cargo-v1` | `starfleet-cargo` | `/details/0` on port `9080` |
| `scout-v1`, `scout-v2`, `scout-v3` | `starfleet-scout` | `/reviews/0` on port `9080`; v2 and v3 call `navcom` for star ratings |
| `navcom-v1` | `starfleet-navcom` | `/ratings/0` on port `9080` |
| `shuttle` | `shuttle` | a client pod with `curl`; send your test requests from here |

Istio 1.30.5 is installed, every pod in `starfleet` has its sidecar, and a `PeerAuthentication` named `default` puts the namespace in **`STRICT`** mTLS. These `AuthorizationPolicy` objects already exist in `starfleet`:

* `allow-nothing` (`spec: {}`): the allow-nothing policy for the whole namespace. **It is correct.**
* `bridge-allow-get`: any caller may `GET` `bridge`. **It is correct.**
* `cargo-allow-bridge`: only `bridge` may `GET` `cargo`. **It is correct.**
* `scout-allow-bridge`: only `bridge` may `GET` `scout`.
* `navcom-allow-scout`: only `scout` may `GET` `navcom`.

Something in the last two is wrong. Fix the problem so that:

1.  Every one of 12 loads of `http://bridge:9080/productpage` from the `shuttle` pod shows the reviews, with no text `currently unavailable` on the page.
2.  At least one of those loads shows star ratings (the HTML contains `glyphicon-star`). Only `scout` v2 and v3 show stars, and they get them from `navcom`.
3.  `scout-allow-bridge` selects the pods with `app: scout` and allows exactly one caller: the `bridge` identity, written as a principal.
4.  `navcom-allow-scout` selects the pods with `app: navcom` and allows exactly one caller: the `scout` identity, written as a principal. The `navcom-v1` proxy must hold this policy.
5.  From the `shuttle` pod, `GET http://bridge:9080/productpage` returns `200`, and `GET` to `http://cargo:9080/details/0`, `http://scout:9080/reviews/0` and `http://navcom:9080/ratings/0` each return `403`.
6.  `allow-nothing` stays in place with an empty `spec`. No policy in `starfleet` may use `rules: [{}]` or a `namespaces` rule for these two policies.
7.  Leave the Deployments, their service accounts, the Services and the `PeerAuthentication` unchanged. Do not add or remove workloads.

A principal is written as `<trust domain>/ns/<namespace>/sa/<service account>`, without `spiffe://`. The trust domain is `cluster.local`.

The grader reads the policies, checks the `navcom-v1` proxy's listener with `istioctl proxy-config`, and sends live requests from the `shuttle` pod, so the fix has to work, not merely exist.
