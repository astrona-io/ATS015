---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

Astronaut, the order is one sentence: *only the tester ship may call the notification service, and only to post a notification.* In sidecar mode that was one policy. This planet runs in ambient mode, where nothing on board can read a signal's contents. A rule about methods and paths does nothing until you build a station that can read them and send the traffic through it.

A few words before you start:

* **Ambient mode** means ships fly without their own communications officer. Shared relay towers do the job instead.
* **ztunnel** is a shared relay tower, one per node. It does the secret handshake and checks ID badges, but it cannot read the signal's contents.
* A **waypoint** is a checkpoint station you build only where someone must read the signal's contents. It is a Gateway API `Gateway` with the class `istio-waypoint`.
* An **L4 rule** checks the envelope (who sent it, which channel). An **L7 rule** reads the letter (method, path, headers). L7 rules need a waypoint.
* An **`AuthorizationPolicy`** is the guard's list. In ambient mode, a policy for a waypoint attaches with **`targetRefs`**, naming the Service the waypoint stands in front of.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `ambient` profile: `istiod` plus the `ztunnel` relay towers, and **no sidecars anywhere**. The Gateway API CRDs are installed.

The planet `ambient-authz` is labelled `istio.io/dataplane-mode=ambient`, so its pods are enrolled in ambient mode. It runs:

| Workload | Service account | Notes |
| --- | --- | --- |
| `notification-service-v1` | `default` | Service `notification-service` on port `80` (container port `8084`), serves `/notify`, no `/admin` handler |
| `tester` | **`tester-sa`** | a `curl` pod |
| `other-client` | **`other-sa`** | a `curl` pod |

No waypoint and no `AuthorizationPolicy` exist yet.

## Your task

1. **Build the checkpoint station.** Deploy a waypoint named `waypoint` in `ambient-authz`. This is the name `istioctl waypoint apply` uses when you give none.
2. **Send the traffic through it.** Enrol the namespace (or the `notification-service` Service) so its traffic uses the waypoint. Creating a waypoint and using it are two separate steps.
3. **Write the rule for the waypoint.** One `AuthorizationPolicy` that attaches with **`targetRefs`** to the Service `notification-service`. It allows only the `tester-sa` identity, and only `POST /notify`. Any other caller, method or path is refused.

The result must be:

| From | Request | Expected |
| --- | --- | --- |
| `other-client` | `POST /notify` | `403` |
| `tester` | `POST /notify` | `200` |
| `tester` | `GET /notify` | `403` |
| `tester` | `POST /admin` | `403` |

## Rules

* No `AuthorizationPolicy` in `ambient-authz` may attach with a label `selector`. Once a waypoint is in the path, the notification pod sees the waypoint's ID badge, not the caller's. A selector rule that names `tester-sa` would then refuse the waypoint itself, and nobody would get through.
* Do not add sidecars or change the data plane mode.
* Do not change any Deployment, Service or ServiceAccount, except for adding the `istio.io/use-waypoint` label if you enrol the Service.

The grader checks that a waypoint exists and is enrolled, that the policy uses `targetRefs` and no `selector`, and that the waypoint holds the authorization filter. Then it sends all four requests.
