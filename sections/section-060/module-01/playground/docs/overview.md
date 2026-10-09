# Overview: Authorization In Ambient Mode, L4 And L7 (Playground)

This is a **playground**, not a lab: a clean sandbox cluster for this module. It
starts a fresh cluster, installs Istio in ambient mode and the Starfleet, and
then waits. There is no task, no `astrona submit` and no pass or fail. Explore,
break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The **Gateway API CRDs**. A waypoint is a Gateway API `Gateway`, so
  `istioctl waypoint apply` needs them.
- **Istio 1.30.5 in ambient mode**, installed with Helm: `istio-base`,
  `istiod` with `profile=ambient` (the control plane), `istio-cni` (it sends
  each pod's traffic to ztunnel) and `ztunnel` (one proxy per node: it
  does the mutual TLS and the L4 rules). There are **no sidecars** anywhere.
- Mesh-wide **access logs**. With no sidecars, only the waypoint you create
  writes them: `kubectl logs -n starfleet deploy/waypoint`. ztunnel writes its
  own log: `kubectl logs -n istio-system ds/ztunnel`.
- Namespace **`starfleet`** (where you work), labelled
  `istio.io/dataplane-mode=ambient`, so every pod is in the mesh with no
  sidecar. Each workload runs as its own service account, which is its identity:
  - **The Starfleet**: `bridge` (`starfleet-bridge`), `cargo`
    (`starfleet-cargo`), `scout` v1, v2, v3 (`starfleet-scout`) and `navcom`
    (`starfleet-navcom`). The product API of `bridge` at
    `http://bridge:9080/api/v1/products/0` calls `cargo` with the identity of
    `bridge`.
  - **`shuttle`** (service account `shuttle`), your client. You send every
    test request from it with `curl`.
  - **`probe`** v1 and v2 (service account `probe`) behind one Service on port
    `8000` (container port `8080`). It echoes any method at `/anything`.
- Every pod shows `1/1`: only the app.
- **No `AuthorizationPolicy` and no waypoint.** Writing them is the point of
  the module.

## Things to try

Each idea below is a small change to the files you made while reading the
module. Edit your saved file, apply it with `kubectl apply -f`, and watch what
happens. The module's parts show the full YAML for every step.

- Run `istioctl ztunnel-config workload | grep -E "NAMESPACE|starfleet"` and
  find `HBONE` in the `PROTOCOL` column for every pod.
- Apply the `cargo` identity rule and send a request from `shuttle` to
  `http://cargo:9080/details/0`. Read the `000`, then find the refusal in
  `kubectl logs -n istio-system ds/ztunnel`.
- Change the `cargo` rule to use `namespaces: ["starfleet"]` instead of a
  principal. Now `shuttle` gets through.
- Add `methods: ["GET"]` to the `cargo` rule, which uses a `selector`. Watch
  `bridge` lose access too: ztunnel fails safe.
- Apply the `probe` method rule with `targetRefs` and no waypoint. A `POST`
  still gets `200`.
- Create the waypoint with `istioctl waypoint apply -n starfleet`, but do not
  label anything. Check that the `POST` still gets `200`.
- Label the `probe` Service with `istio.io/use-waypoint=waypoint` and send the
  `POST` again. Now it gets `403`.
- Attach the `probe` rule to the waypoint `Gateway` instead of the Service
  (`kind: Gateway`, `group: gateway.networking.k8s.io`) and compare.
- Label the whole namespace with `istio.io/use-waypoint=waypoint` while the
  `cargo` identity rule is in place. Ask the product API of `bridge` again and
  work out why `cargo` now refuses it.
- Remove the waypoint with `istioctl waypoint delete waypoint -n starfleet`
  and watch the method rule go quiet while the `cargo` rule keeps working.
- Compare `istioctl ztunnel-config policy` with
  `kubectl get authorizationpolicy -n starfleet`.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
istioctl waypoint delete --all -n starfleet
kubectl label namespace starfleet istio.io/use-waypoint-
kubectl label service --all -n starfleet istio.io/use-waypoint-
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-060-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-060-01`.
- A pod does not show `HBONE` in `istioctl ztunnel-config workload`: check
  the namespace label with `kubectl get namespace starfleet --show-labels`, and
  that the `istio-cni` and `ztunnel` pods run in `istio-system`.

## When you're done

```sh
astrona destroy ats-015-playground-060-01
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

Two exam-style tasks for this playground. Start the playground
first. Try each task on your own, then open the solution.

Start each task from a clean namespace: no `AuthorizationPolicy`, no waypoint.
The commands in "Start over without a new cluster" above get
you there.

### Task 1: allow only `bridge` to reach `scout`

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

### Task 2: read-only access to the probe, enforced by a waypoint

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
