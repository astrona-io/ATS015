# Practice: Authorization In Ambient Mode, L4 And L7

Two exam-style tasks for this playground. Start the playground
first. Try each task on your own, then open the solution.

Start each task from a clean namespace: no `AuthorizationPolicy`, no waypoint.
The commands in [overview.md](./overview.md#start-over-without-a-new-cluster)
get you there.

## Task 1: allow only `bridge` to reach `scout`

> In namespace `starfleet`, which runs in ambient mode with no waypoint, allow
> only workloads running as the service account `starfleet-bridge` to connect
> to the `scout` pods (all three versions). Use one `AuthorizationPolicy`
> named `scout-l4`. Prove that `shuttle` is refused and that `bridge`
> still gets the `scout` answers.

<details><summary>Solution</summary>

Every field the task needs is about the caller's identity, so ztunnel can
enforce it alone. Use a `selector` on `app: scout`, which every `scout` version
carries, not `targetRefs`.

Save this as `authorizationpolicy-scout-l4.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: scout-l4
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: scout
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-bridge
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-scout-l4.yaml
```

Then check the result. First from `shuttle`, straight to `scout`:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://scout:9080/reviews/0
```

```text
000
command terminated with exit code 56
```

Then ask the reviews API of `bridge`, which calls `scout` with the identity
of `bridge`:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://bridge:9080/api/v1/products/0/reviews
```

```text
200
```

Give the rule about a minute to reach live traffic before you test. The `shuttle` pod gets `000`: ztunnel closed the connection. `bridge` still
gets its answers.

</details>

## Task 2: read-only access to the probe, enforced by a waypoint

> In namespace `starfleet`, allow only the `shuttle` service account to call
> the `probe` Service, and only with `GET`. Deploy a waypoint named `waypoint`
> and send **only** the `probe` Service through it. Attach the policy with
> `targetRefs`. A `POST` from `shuttle` must get `403`.

<details><summary>Solution</summary>

`GET` is a method, so the rule needs a waypoint. Create it first, then send
the traffic for `probe` through it.

```sh
istioctl waypoint apply -n starfleet
kubectl wait --for=condition=Programmed gateway/waypoint -n starfleet --timeout=120s
kubectl label service probe -n starfleet istio.io/use-waypoint=waypoint
```

```text
✅ waypoint starfleet/waypoint applied
gateway.gateway.networking.k8s.io/waypoint condition met
service/probe labeled
```

Save this as `authorizationpolicy-probe-l7.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-l7
  namespace: starfleet
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/shuttle
    to:
    - operation:
        methods: ["GET"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-l7.yaml
```

Then check the result:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "GET:  %{http_code}\n" -X GET http://probe:8000/anything
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "POST: %{http_code}\n" -X POST http://probe:8000/anything
```

```text
GET:  200
POST: 403
```

If the `POST` still gets `200`, wait about a minute and try again. The `403` comes from the waypoint. Only the `probe` Service carries the
`istio.io/use-waypoint` label, so every other Service keeps the direct ztunnel
path.

</details>
