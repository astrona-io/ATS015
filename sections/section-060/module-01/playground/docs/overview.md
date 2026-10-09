# Overview: Authorization In Ambient Mode, L4 And L7 (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio in ambient mode and the Starfleet, and
then waits. There is no task, no `astrona submit` and no pass or fail. Explore,
break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The **Gateway API CRDs**. A waypoint is a Gateway API `Gateway`, so
  `istioctl waypoint apply` needs them.
- **Istio 1.30.5 in ambient mode**, installed with Helm: `istio-base`,
  `istiod` with `profile=ambient` (mission control), `istio-cni` (it sends
  each pod's traffic to ztunnel) and `ztunnel` (one relay station per node: it
  does the mutual TLS and the L4 rules). There are **no sidecars** anywhere.
- Mesh-wide **access logs**. With no sidecars, only the waypoint you create
  writes them: `kubectl logs -n starfleet deploy/waypoint`. ztunnel writes its
  own log: `kubectl logs -n istio-system ds/ztunnel`.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio.io/dataplane-mode=ambient`, so every ship is in the mesh with no
  sidecar. Each ship runs as its own service account, which is its identity:
  - **The Starfleet**: `bridge` (`starfleet-bridge`), `cargo`
    (`starfleet-cargo`), `scout` v1, v2, v3 (`starfleet-scout`) and `navcom`
    (`starfleet-navcom`). The bridge's product API at
    `http://bridge:9080/api/v1/products/0` signals `cargo` with the bridge's
    identity.
  - **`shuttle`** (service account `shuttle`), your client. You send every
    test signal from it with `curl`.
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
  find `HBONE` in the `PROTOCOL` column for every ship.
- Apply the `cargo` identity rule and send a signal from the shuttle to
  `http://cargo:9080/details/0`. Read the `000`, then find the refusal in
  `kubectl logs -n istio-system ds/ztunnel`.
- Change the `cargo` rule to use `namespaces: ["starfleet"]` instead of a
  principal. Now the shuttle gets through.
- Add `methods: ["GET"]` to the `cargo` rule, which uses a `selector`. Watch
  the bridge lose access too: ztunnel fails safe.
- Apply the `probe` method rule with `targetRefs` and no waypoint. A `POST`
  still gets `200`.
- Create the waypoint with `istioctl waypoint apply -n starfleet`, but do not
  label anything. Check that the `POST` still gets `200`.
- Label the `probe` Service with `istio.io/use-waypoint=waypoint` and send the
  `POST` again. Now it gets `403`.
- Attach the `probe` rule to the waypoint `Gateway` instead of the Service
  (`kind: Gateway`, `group: gateway.networking.k8s.io`) and compare.
- Label the whole namespace with `istio.io/use-waypoint=waypoint` while the
  `cargo` identity rule is in place. Ask the bridge's product API again and
  work out why `cargo` now refuses it.
- Remove the waypoint with `istioctl waypoint delete waypoint -n starfleet`
  and watch the method rule go quiet while the `cargo` rule keeps working.
- Compare `istioctl ztunnel-config policy` with
  `kubectl get authorizationpolicy -n starfleet`.

For exam-style practice with solutions, see [practice.md](./practice.md).

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
- A ship does not show `HBONE` in `istioctl ztunnel-config workload`: check
  the namespace label with `kubectl get namespace starfleet --show-labels`, and
  that the `istio-cni` and `ztunnel` pods run in `istio-system`.

## When you're done

```sh
astrona destroy ats-015-playground-060-01
```

(`astrona destroy` takes the environment name, not the configuration path.)
