# Overview: Authorize By Source IP At The Ingress Gateway (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile — including the
  `istio-ingressgateway` Deployment in `istio-system` — plus `istioctl` on your
  PATH.
- One injected namespace, **`gwauthz-demo`**: `booking-service-v1` (serving
  `/book`) and `notification-service-v1`.
- A **`Gateway` and `VirtualService`** for `booking.ica.local` on port 80,
  applied at bootstrap. They are the target of your policies, not the subject.
- **No `AuthorizationPolicy`**, and **no `gatewayTopology.numTrustedProxies`**.

> **No load balancer on `kind`.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80`.
> Remember that a port-forward makes the connection appear to come from inside
> the cluster — read the gateway access log before trusting any CIDR.

## Things to try

- Before writing a policy, find the source address the gateway actually sees, in
  `kubectl -n istio-system logs deploy/istio-ingressgateway`.
- Apply an `ipBlocks` allow-list for the address you just found, and then for
  one you invented. Compare.
- Use `remoteIpBlocks` **without** setting `numTrustedProxies`, and try to
  bypass it by setting `X-Forwarded-For` yourself.
- Set `numTrustedProxies: 1`, re-run the same bypass attempt, and see what
  changed.
- Set `numTrustedProxies: 2` and work out which element of a two-address
  `X-Forwarded-For` the rule now reads.
- Create the same policy in `gwauthz-demo` instead of `istio-system` and confirm
  it does nothing at all.
- Combine an IP rule with `paths: ["/admin*"]` so only one path is restricted.
- Send a denied request and check whether it appears in the application's logs.
  (It should not — that is the point of enforcing at the edge.)

## When you're done

```sh
astrona destroy ats-015-playground-050-01
```

(`astrona destroy` takes the environment name, not the config path.)
