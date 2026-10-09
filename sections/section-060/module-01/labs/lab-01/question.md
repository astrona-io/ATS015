---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Your platform team moved namespace `ambient-authz` to ambient mode. The sidecars are gone and nothing had to restart. Then someone ported the old authorization policy across, saw it in `kubectl get`, and closed the ticket. An audit later found that its method rule was never enforced. Do it properly this time.

The cluster runs Istio 1.30.5 in **ambient mode**: `istiod`, `istio-cni` and the `ztunnel` DaemonSet, and **no sidecars anywhere**. The Gateway API CRDs are installed. Namespace `ambient-authz` carries the label `istio.io/dataplane-mode=ambient`, so its pods are already in the mesh. It runs:

| Workload | Service account | Notes |
| --- | --- | --- |
| `notification-service-v1` | `default` | container port `8084`, Service `notification-service` on port `80` |
| `tester` | `tester-sa` | a client pod with `curl` |
| `other-client` | `other-sa` | a client pod with `curl` |

No waypoint and no `AuthorizationPolicy` exist yet.

In namespace `ambient-authz`, for `notification-service`:

1.  Deploy a waypoint, and send the traffic for `notification-service` through it (label the namespace or the Service with `istio.io/use-waypoint`). A method is an L7 field, and ztunnel alone does not read requests.
2.  Allow **only** the `tester-sa` identity, and only the **`POST`** method. `other-sa` must be refused, and so must a `GET` from `tester-sa`.
3.  Attach the policy with **`targetRefs`** that names the Service, not with a label `selector`.
4.  Write it as **one** `AuthorizationPolicy`. Do not add a second, pod-level policy that allows only `tester-sa`: behind a waypoint, every connection reaches the pod with the waypoint's own identity, so such a rule refuses the waypoint and the service stops answering anyone.

The result must be:

| From | Request to `http://notification-service/notify` | Expected |
| --- | --- | --- |
| `other-client` | `POST` | `403` (refused by the waypoint) |
| `tester` | `POST` | `200` |
| `tester` | `GET` | `403` |

Constraints:

* Do not add sidecars or change the dataplane mode.
* Do not change any Deployment, Service selector, port or ServiceAccount.

The grader checks that a waypoint `Gateway` exists and is programmed, that traffic is enrolled through it, and that a policy uses `targetRefs`. Then it sends the three calls above, so the policy has to work, not only exist.
