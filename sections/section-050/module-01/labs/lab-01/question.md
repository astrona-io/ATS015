---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

A range of addresses has been hammering the booking service. The platform team wants it cut off at the ingress gateway, not at the app, which is already wasting connections on requests nobody wants. A load balancer sits in front of the gateway, and the last attempt at this blocked either nobody or everybody.

The cluster runs Istio 1.30.5, installed with `istioctl` and the `demo` profile:

* The ingress gateway runs in the namespace `istio-system`. Its pods carry the label `istio: ingressgateway`.
* The gateway already trusts **one** proxy hop in front of it (`numTrustedProxies: 1`, set in the gateway's proxy configuration). This is a precondition: you write policy, not an install.
* The namespace `gwauthz-demo` has sidecar injection on and runs `booking-service-v1` (it serves `/book`), `notification-service-v1` and a `tester` pod.
* A `Gateway` and a `VirtualService` for the host `booking.ica.local` on port `80` already exist. They are the target of your policy, not part of the task.
* No `AuthorizationPolicy` exists.

`kind` has no load balancer. Reach the gateway with a port forward:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
```

The port forward also acts like a proxy: the gateway sees every connection come from inside the cluster.

Deny requests from the client range **`192.168.0.0/16`** at the ingress gateway, and let every other client reach `booking.ica.local`:

1.  Create an `AuthorizationPolicy` in the **gateway's** namespace that selects the ingress gateway pod.
2.  Match the **original client** address, the one a trusted proxy forwarded in `X-Forwarded-For`, not the address of whatever opened the connection.
3.  Deny `192.168.0.0/16`. Do not close anything else.

When you call `http://127.0.0.1:8080/book` with the header `Host: booking.ica.local`:

| Request | Expected |
| --- | --- |
| `X-Forwarded-For: 10.1.2.3` | `200` |
| `X-Forwarded-For: 192.168.5.5` | `403` |

Constraints:

* Do not change the `Gateway` or the `VirtualService`.
* Do not reinstall Istio, and do not change the gateway's proxy configuration.
* An `ALLOW` policy that closes the whole gateway is not a solution: callers outside the range must still get through.

The grader checks the policy's namespace, selector and source field, checks that the gateway still trusts one proxy hop, and then sends both requests through the gateway.
