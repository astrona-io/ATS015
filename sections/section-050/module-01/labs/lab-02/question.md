---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

Astronaut, the bridge's API on `/api/v1/products` is reachable through the arrival gate by anyone. Mission control wants it open only to the office network, **`203.0.113.0/24`**. The bridge's page must stay open for everyone. A load balancer sits in front of the gate.

The cluster runs Istio 1.30.5, installed with Helm:

* The ingress gateway runs in the namespace `istio-ingress`. Its Deployment and Service are called `istio-ingress`, and its pods carry the label `istio: ingress`.
* Every gateway already trusts **one** proxy hop in front of it (`numTrustedProxies: 1`). This is a precondition: do not change it.
* The namespace `starfleet` runs the Starfleet. A `Gateway` named `starfleet-gateway` and a `VirtualService` named `starfleet` send the host `starfleet.example.com` on port `80` to the `bridge`: its page is on `/productpage` and its API on `/api/v1/products`.
* No `AuthorizationPolicy` exists.

`kind` has no load balancer. Reach the gateway with a port forward:

```bash
kubectl -n istio-ingress port-forward svc/istio-ingress 8080:80 >/dev/null 2>&1 &
```

Create one `AuthorizationPolicy` named **`api-office-only`** so that:

1.  It guards the ingress gateway pod.
2.  Signals to `/api/v1/products`, and to every path below it, on `starfleet.example.com` are refused with `403` unless the original client address is in `203.0.113.0/24`.
3.  The client address is the one the trusted proxy forwarded in `X-Forwarded-For`, not the address of whatever opened the connection.
4.  Every other path stays open for every client.

When you call `http://127.0.0.1:8080` with the header `Host: starfleet.example.com`:

| Path | `X-Forwarded-For` | Expected |
| --- | --- | --- |
| `/api/v1/products` | `203.0.113.7` | `200` |
| `/api/v1/products` | `10.1.2.3` | `403` |
| `/api/v1/products/0` | `10.1.2.3` | `403` |
| `/productpage` | `10.1.2.3` | `200` |
| `/api/v1/products` | `203.0.113.7, 10.1.2.3` | `403` |

Constraints:

* Do not change the `Gateway`, the `VirtualService` or the workloads.
* Do not reinstall Istio or change `numTrustedProxies`.

The grader checks the policy's namespace and selector, checks that the gateway still trusts one proxy hop, and then sends live signals through the gateway, including some that are not in the table.
