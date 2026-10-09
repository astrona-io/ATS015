# Bring The Drifter Into The Fleet

Astronaut, the counter showed plain signals, and the flight log named the sender: the drifter on `outpost`. It cannot do the mTLS handshake because it has no communications officer on board. This part puts one on board.

It is the step with the real work in it. In a real cluster, it is also the only step that disrupts anything, because ships have to be relaunched.

## How a ship gets its communications officer

Sidecar injection is how the `istio-proxy` container gets into a pod. This section shows when it happens, because the timing explains the behaviour that surprises almost everyone.

### The inspector at the launch pad

Injection is done by a **mutating admission webhook**. Think of it as an inspector at the launch pad. Kubernetes calls the inspector while a new pod is being created. If the planet carries the label `istio-injection=enabled`, the inspector adds the `istio-proxy` container to the pod spec before the ship launches.

```mermaid
sequenceDiagram
    participant K as Kubernetes API
    participant W as istiod webhook
    participant P as new pod
    K->>W: pod is being created
    W->>K: add istio-proxy
    K->>P: launch with sidecar
```

The Kubernetes API server asks the webhook, which runs inside `istiod`, about every new pod on a labelled planet. The webhook answers with the changed pod spec, and only then is the pod stored and started.

### Ships already flying are not touched

The webhook runs **only when a pod is created**. It has no way to reach a pod that is already running. A running pod's list of containers cannot change. So labelling a planet changes nothing for the ships already flying. The next ship launched there gets a communications officer, and that is all.

That makes the **restart** the real migration step. `kubectl rollout restart` replaces the pods of a Deployment one by one. Each new pod passes the inspector on its way out.

## See it in your playground

Here you label the `outpost` planet, see that nothing changes, and then relaunch the drifter.

<!-- astrona:playground:renew -->

### Label the planet

Switch injection on for `outpost`, then list its pods:

```sh
kubectl label namespace outpost istio-injection=enabled
kubectl -n outpost get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
```

```text
namespace/outpost labeled
POD                        CONTAINERS   INIT
drifter-57f4b7dc54-24fm7   drifter      <none>
```

One container and no init containers. The label is there, but the drifter launched before it, so it still flies alone.

### Relaunch the drifter

Restart the Deployment, wait for it, and list the containers again:

```sh
kubectl -n outpost rollout restart deployment drifter
kubectl -n outpost rollout status deployment drifter
kubectl -n outpost get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
```

```text
deployment.apps/drifter restarted
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
deployment "drifter" successfully rolled out
POD                        CONTAINERS   INIT
drifter-56479465c8-s7hcz   drifter      istio-init,istio-proxy
```

The new pod has a new name, and `istio-proxy` is now on board. Look where it sits: in the `INIT` column, not next to `drifter`. On this cluster, Istio 1.30 adds the proxy as a **native sidecar**: a special init container that starts before the app and keeps running beside it for the pod's whole life. `kubectl get pods` shows the drifter as `2/2` either way. The drifter now has a communications officer, so its signals to `cargo` use the mTLS handshake.

If you list only `.spec.containers`, you see one container and may think the injection failed. Always check the init containers too, or simply the `READY` column.

Two things follow from this way of working:

- **A pod that no controller owns does not come back.** A bare `Pod`, with no Deployment or StatefulSet behind it, has nothing to recreate it. `rollout restart` does not apply, and deleting it just removes it. Find those before the maintenance window, not during it.
- **The new pod keeps the same identity.** A ship's identity comes from its namespace and service account, for example `spiffe://cluster.local/ns/outpost/sa/default` for the drifter. The new pod gets a new certificate with the same identity, so policies written for it keep working.

## Measure again

Before you switch to `STRICT`, check that no plain signals arrive any more. The counter still holds the old `none` signals, because counters only go up. So the question is not "is it zero?" but "did it stop going up?".

### Read, send, read again

If `plain_signals` is not defined in this terminal, paste it first. Then read the tally, send 5 signals from the drifter, and read the tally again:

```sh
plain_signals() {
  kubectl -n starfleet exec deploy/cargo-v1 -c istio-proxy -- \
    pilot-agent request GET stats/prometheus \
    | grep '^istio_requests_total' | grep 'reporter="destination"' \
    | sed -n 's/.*connection_security_policy="\([^"]*\)".* \([0-9]*\)$/\1 \2/p' \
    | awk '{sum[$1]+=$2} END {for (k in sum) print k, sum[k]}'
}
plain_signals
for i in $(seq 1 5); do
  kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter %{http_code}\n' http://cargo.starfleet:9080/details/0
done | sort | uniq -c
plain_signals
```

```text
2026/10/09 07:16:25 INFO GOMEMLIMIT is already set, skipping package=github.com/KimMachineGun/automemlimit/memlimit GOMEMLIMIT=1073741824
mutual_tls 12
none 17
   5 drifter 200
2026/10/09 07:16:25 INFO GOMEMLIMIT is already set, skipping package=github.com/KimMachineGun/automemlimit/memlimit GOMEMLIMIT=1073741824
mutual_tls 17
none 17
```

Your numbers depend on how many signals you sent before. What matters is the change between the two readings.

The `none` number did not move. The `mutual_tls` number went up by 5: the drifter's new signals arrive with the handshake. Only when nothing **new** arrives as `none` is the planet ready for the switch.

`kubectl exec deploy/drifter` picks one pod of the Deployment. If you run it while the old pod is still shutting down, it can pick the old one, and the signal goes out plain. Wait until `rollout status` reports success.

> *A label tells the launch inspector what to do next time. Only a relaunch puts the communications officer on board, so the restart, not the label, is the migration.*

## Common pitfalls

> [!WARNING]
> - **Expecting the label to work at once.** Injection happens when a pod is created. Nothing changes until the pods are restarted.
> - **Restarting a pod that no controller owns.** A deleted bare pod is gone. Check for a Deployment or StatefulSet first.
> - **Checking for zero.** The old `none` signals stay in the counter. Check that the number stopped going up.
> - **Testing against the old pod.** During a rollout, `kubectl exec deploy/...` can still reach the pod without a sidecar. Wait for `rollout status`.
