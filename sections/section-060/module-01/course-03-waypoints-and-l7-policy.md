# Part 3 — Waypoints and L7 policy

> Prerequisite: [Part 2 — What ztunnel can enforce](./course-02-what-ztunnel-can-enforce.md). Next: [Part 4 — Tooling, and carrying sidecar knowledge across](./course-04-tooling-and-carrying-across.md).

Add a field ztunnel cannot evaluate and the policy is still accepted. It is stored, listed, and completely ignored. This part demonstrates that deliberately — it is the single most examinable thing about ambient mode — then deploys the component that makes the same policy work, with nothing about the policy changing.

## A rule with nowhere to run

Restricting the method to `POST` needs the parsed request, which ztunnel does not produce. There is no validation error for that: the API server checks the schema, and `methods` is a perfectly valid field.

So the object is written, accepted, and has no component capable of enforcing it:

```text
   AuthorizationPolicy with methods: ["POST"]
        │
        ├─ kubectl apply                 → created
        ├─ kubectl get authorizationpolicy → listed, alongside the working L4 one
        ├─ istioctl analyze              → typically clean
        └─ traffic                       → completely unaffected
```

This module also introduces the other ambient change, in how such a policy attaches.

## `targetRefs` instead of `selector`

Ambient prefers `targetRefs` for L7 policy:

```yaml
spec:
  targetRefs:
    - kind: Service
      group: ""
      name: notification-service
```

against the `selector` form used for L4 in [Part 2](./course-02-what-ztunnel-can-enforce.md). The distinction reflects what is actually being pointed at:

```text
   selector: matchLabels        →  these PODS
        │                          ztunnel enforces at each pod's connection
        │                          right for L4
        │
   targetRefs: kind: Service    →  the waypoint IN FRONT OF that service
        │                          L7 enforcement happens there, not at the pod
        │
   targetRefs: kind: Gateway    →  the waypoint itself
                                   (a Gateway API Gateway — what a waypoint is)
```

L7 enforcement does not happen at a pod. It happens at the waypoint the traffic passes through, so the policy names the service whose waypoint should hold it — or the waypoint directly. Using a `selector` for an L7 rule points at pods, where no HTTP-capable component exists, and is a second way to write a rule nothing enforces.

The `group: ""` is the Kubernetes core API group, which is where `Service` lives. A Gateway API `Gateway` would use `group: gateway.networking.k8s.io`.

> [!TIP]
> **Try it — an L7 rule that is accepted and does nothing**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: notification-l7
>   namespace: ambient-authz
> spec:
>   targetRefs:
>     - kind: Service
>       group: ""
>       name: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             principals:
>               - cluster.local/ns/ambient-authz/sa/tester-sa
>       to:
>         - operation:
>             methods: ["POST"]
> YAML
>
> sleep 3
> kubectl -n ambient-authz get authorizationpolicy
> kubectl -n ambient-authz exec deploy/tester -- \
>   curl -s -o /dev/null -w 'GET  (should be blocked): %{http_code}\n' -X GET http://notification-service/notify
> kubectl -n ambient-authz exec deploy/tester -- \
>   curl -s -o /dev/null -w 'POST (allowed):           %{http_code}\n' -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> NAME              AGE
> notification-l4   2m
> notification-l7   3s
> GET  (should be blocked): 200
> POST (allowed):           200
> ```
>
> Both policies listed; only one doing anything. The `GET` should have been refused by `notification-l7` and was not, because no component in the path can see that it was a `GET`. The policy is not wrong — it is unenforced, and those are very different problems with the same appearance.

## Deploying a waypoint

A waypoint is created with `istioctl waypoint apply`, which generates a Gateway API `Gateway` (with `gatewayClassName: istio-waypoint`) and the Deployment behind it. `--enroll-namespace` additionally labels the namespace so its services route through that waypoint.

The two steps are separate for a reason, and conflating them is a documented way to waste an afternoon:

```text
   istioctl waypoint apply           → the waypoint EXISTS
        │                               a Gateway, a Deployment, a running Envoy
        │                               PROGRAMMED: True
        │
   --enroll-namespace (or a label)   → traffic GOES THROUGH it
        (istio.io/use-waypoint)         without this, the waypoint runs and
                                        receives nothing
```

A waypoint that exists but is not enrolled looks entirely healthy: the pod is ready, the `Gateway` reports `PROGRAMMED: True`, and no L7 policy is enforced because no traffic reaches it.

Once traffic does flow through it, the path gains a hop:

```text
   before:  tester ──▶ ztunnel ══HBONE══▶ ztunnel ──▶ notification-service
                          L4 only

   after:   tester ──▶ ztunnel ══HBONE══▶ waypoint ══HBONE══▶ ztunnel ──▶ notification-service
                          L4                 L7                  L4
```

ztunnel still does L4 at both ends; the waypoint is inserted in between and is the only thing that parses HTTP. That is also the cost: an extra network hop and an extra Envoy to run, which is exactly the cost ambient mode exists to let you avoid where it is not needed.

> [!TIP]
> **Try it — add a waypoint and watch the same policy start working**
>
> ```sh
> istioctl waypoint apply -n ambient-authz --enroll-namespace
> kubectl -n ambient-authz rollout status deployment waypoint
> kubectl -n ambient-authz get gateway
>
> kubectl -n ambient-authz exec deploy/tester -- sh -c \
>   'curl -s -o /dev/null -w "POST: %{http_code}\n" -X POST http://notification-service/notify;
>    curl -s -o /dev/null -w "GET:  %{http_code}\n" -X GET  http://notification-service/notify'
> ```
>
> Expect something like:
>
> ```text
> NAME       CLASS            ADDRESS        PROGRAMMED
> waypoint   istio-waypoint   10.96.x.x      True
> POST: 200
> GET:  403
> ```
>
> Nothing about `notification-l7` changed — same object, same rules, same `targetRefs`. Adding a component that can read HTTP is what turned it on. And the `GET` now fails with **`403`**, an HTTP-level refusal, in contrast to the `000` an L4 denial produced in [Part 2](./course-02-what-ztunnel-can-enforce.md) — the two-component failure vocabulary, visible in one namespace.
>
> This adds a Deployment and changes the traffic path. Remove it with `istioctl waypoint delete -n ambient-authz`, and the enrolment with `kubectl label namespace ambient-authz istio.io/use-waypoint-`; the L7 rule then goes quiet again while the L4 rule keeps working.

That last experiment — remove the waypoint, watch one policy survive and the other stop mattering — is the clearest single demonstration of the split, and worth running once.

## Scope: namespace or service

`--enroll-namespace` routes every service in the namespace through one waypoint. The alternative is per-service enrolment, labelling only the services that need L7:

```sh
kubectl -n ambient-authz label service notification-service istio.io/use-waypoint=waypoint
```

Per-service is the narrower default when only one or two services need L7 rules: everything else keeps the cheaper ztunnel-only path. Namespace-wide is simpler to reason about when most services need it, and is what the playground uses to keep the demonstration short.

Either way the policy's `targetRefs` stays the same — it names the service or the gateway, and enrolment decides whether traffic actually arrives there.

> *A waypoint that exists is not a waypoint that receives traffic, and an L7 rule with nothing to enforce it is accepted, listed, and silently ignored.*

## Common pitfalls

> [!WARNING]
> **Deploying a waypoint and expecting traffic to use it.** The destination has to be associated with it; otherwise ztunnel routes straight through.
>
> **Forgetting the Gateway API CRDs.** A waypoint is a `Gateway`; without them the apply fails outright.
>
> **Assuming one waypoint covers everything.** They are scoped to a namespace or a service, and the scope decides what they can enforce.
>
> **Reading the extra hop as overhead to remove.** It is where every L7 decision happens; removing it removes the enforcement with it.

## Reference

- [Ambient L7 features](https://istio.io/latest/docs/ambient/usage/l7-features/) — which capabilities require a waypoint, and what happens without one.
- [Waypoint proxies](https://istio.io/latest/docs/ambient/usage/waypoint/) — `istioctl waypoint apply`, enrolment labels, and per-service scoping.
- [AuthorizationPolicy `targetRefs`](https://istio.io/latest/docs/reference/config/security/authorization-policy/) — the attachment field and its `kind` / `group` values.
