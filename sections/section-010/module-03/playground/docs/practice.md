# Practice: Migrate A Namespace From PERMISSIVE To STRICT mTLS

Two exam-style tasks for this playground, astronaut. Start the playground
first, and paste the `plain_signals` helper from
[overview.md](./overview.md#helpers).

Try each task on your own first, then open the solution.

## Task 1: move the planet to STRICT without breaking anyone

> Namespace `starfleet` must accept **only mTLS**. The `drifter` in namespace
> `outpost` must still reach `http://cargo.starfleet:9080/details/0` with
> `200` afterwards. Do not move the drifter to another namespace.

<details><summary>Solution</summary>

Work in the safe order: write down `PERMISSIVE`, bring the caller into the
fleet, and only then switch to `STRICT`.

Save this as `peerauthentication-starfleet-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: PERMISSIVE
```

Apply it:

```bash
kubectl apply -f peerauthentication-starfleet-permissive.yaml
```

Bring the drifter into the fleet. The label only works for ships that launch
after it, so restart the drifter:

```bash
kubectl label namespace outpost istio-injection=enabled
kubectl -n outpost rollout restart deploy/drifter
kubectl -n outpost rollout status deploy/drifter
kubectl -n outpost get pods
```

```text
namespace/outpost labeled
deployment.apps/drifter restarted
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
deployment "drifter" successfully rolled out
NAME                       READY   STATUS    RESTARTS   AGE
drifter-67f55b45b7-2vmh9   2/2     Running   0          2s
```

Save this as `peerauthentication-starfleet-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
```

Apply it:

```bash
kubectl apply -f peerauthentication-starfleet-strict.yaml
```

Wait about a minute, so the new orders reach every open connection. Then
check the result:

```bash
kubectl -n outpost exec deploy/drifter -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://cargo.starfleet:9080/details/0
```

```text
200
```

</details>

## Task 2: take the sidecar off again, safely

> Start from the end of task 1: `starfleet` is `STRICT`, and the `drifter` in
> `outpost` has a sidecar. The drifter's owners want the sidecar off their
> ship again. Remove it, and keep the drifter able to reach
> `http://cargo.starfleet:9080/details/0` with `200` the whole time. You may
> move `starfleet` back to `PERMISSIVE`.

<details><summary>Solution</summary>

Undo in the reverse order of the migration: first `PERMISSIVE`, then remove
the sidecar. The other way round, the drifter sends plain signals to a
`STRICT` planet and gets a connection reset.

Apply the `PERMISSIVE` file from task 1 again:

```bash
kubectl apply -f peerauthentication-starfleet-permissive.yaml
```

Wait about a minute, so the new orders reach every proxy. Then switch
injection off for `outpost` and relaunch the drifter without a sidecar:

```bash
kubectl label namespace outpost istio-injection-
kubectl -n outpost rollout restart deploy/drifter
kubectl -n outpost rollout status deploy/drifter
kubectl -n outpost get pods
```

```text
namespace/outpost unlabeled
deployment.apps/drifter restarted
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
deployment "drifter" successfully rolled out
NAME                       READY   STATUS    RESTARTS   AGE
drifter-5589564f74-qmkd5   1/1     Running   0          0s
```

Then check the result:

```bash
kubectl -n outpost exec deploy/drifter -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://cargo.starfleet:9080/details/0
```

```text
200
```

</details>
