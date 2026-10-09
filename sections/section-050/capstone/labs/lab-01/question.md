---
estimated_duration: 30m
---

# Question

Solve this question on: `terminal`

Two requests reached the platform team on the same day. The abuse team wants one range of addresses cut off completely: it has been flooding the booking API, and none of that traffic is real. The operations team wants the admin path reachable only from the office network. The ingress gateway is shared with other services, so you must not block anything you were not asked to block.

A few words before you start:

* The **ingress gateway** is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. An `AuthorizationPolicy` in `istio-system` that selects the gateway pod is enforced at the gateway.
* An **`AuthorizationPolicy`** allows or denies requests to a workload. `ALLOW` lists the requests that may pass, and `DENY` lists the requests that are blocked. `DENY` policies are checked first.
* Every request has a **source address** (the client IP). Requests that pass through proxies also carry the header `X-Forwarded-For`, a list of the addresses they passed.
* **`numTrustedProxies`** says how many proxies in front of the gateway to trust when reading that list. **`remoteIpBlocks`** matches the original client address worked out that way. **`ipBlocks`** matches only whoever opened the connection, which behind a proxy is the proxy.

## What is in the cluster

The cluster runs Istio 1.30.5, installed with the `demo` profile. The ingress gateway runs in `istio-system` with the label `istio: ingressgateway`. It is already set to trust **one** proxy hop in front of it (`numTrustedProxies: 1`).

The namespace `gwauthz-demo` has sidecar injection on and runs `booking-service-v1` (serves `/book`, and has **no `/admin` handler**) and `notification-service-v1`. A `Gateway` and a `VirtualService` already expose `booking.ica.local` on port `80` of the gateway.

`booking-service` has no `/admin` handler. So an `/admin` request that is **not** blocked comes back `404` from the app. That is how you tell "denied at the gateway" (`403`) from "reached the app" (`404`).

No `AuthorizationPolicy` exists yet.

`kind` has no load balancer. Reach the gateway with `kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80`.

## Your task

Write two rules at the gateway:

1. **A global block-list.** Clients in `192.168.0.0/16` are denied everything on this gateway.
2. **An office-only admin path.** Requests for `/admin` **and anything below it** are denied **unless** the client is in `203.0.113.0/24`. Every other path stays open to everyone not caught by rule 1.

Both rules must match the **original client** address, not the address of whatever opened the connection.

The result, calling with `Host: booking.ica.local`, must be:

| `X-Forwarded-For` | Path | Expected |
| --- | --- | --- |
| `10.1.2.3` | `/book` | `200` |
| `192.168.5.5` | `/book` | `403` |
| `10.1.2.3` | `/admin` | `403` |
| `203.0.113.9` | `/admin` | not `403` |
| `192.168.5.5` | `/admin` | `403` |

## Leave alone

* Do not change the `Gateway` or the `VirtualService`, and do not reinstall Istio.
* Rule 2 must not close anything other than the `/admin` paths.

The grader checks that your policies sit in `istio-system`, select the ingress gateway and use `remoteIpBlocks` or `notRemoteIpBlocks`, and then sends all five requests through the gateway.
