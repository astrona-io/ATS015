# Solution Walkthrough

The safe order is the whole answer: write down `PERMISSIVE`, add a sidecar to the plain-text client, measure again, and only then switch to `STRICT`. Switch first, and `outside-client` is cut off until you fix it.

---

## Step 1: Count the plain-text requests

Send 10 requests from each client, then read the counter on the **receiving** proxy, `notification-service-v1`. The pipeline adds up the requests for each value of `connection_security_policy`:

```sh
for i in $(seq 1 10); do
  kubectl -n migrate-demo exec deploy/tester -- curl -s -o /dev/null -X POST http://notification-service/notify
  kubectl -n outside exec deploy/outside-client -- curl -s -o /dev/null -X POST http://notification-service.migrate-demo/notify
done
kubectl -n migrate-demo exec deploy/notification-service-v1 -c istio-proxy -- \
  pilot-agent request GET stats/prometheus \
  | grep '^istio_requests_total' | grep 'reporter="destination"' \
  | sed -n 's/.*connection_security_policy="\([^"]*\)".* \([0-9]*\)$/\1 \2/p' \
  | awk '{sum[$1]+=$2} END {for (k in sum) print k, sum[k]}'
```

```text
2026/10/09 07:28:18 INFO GOMEMLIMIT is already set, skipping package=github.com/KimMachineGun/automemlimit/memlimit GOMEMLIMIT=1073741824
mutual_tls 10
none 10
```

The first line is an information message from `pilot-agent`; ignore it. The two counter lines can come out in either order.

`none` is there, so a switch to `STRICT` right now would break a client. The `-c istio-proxy` matters: the counter lives in the sidecar, not in the app.

## Step 2: Write down the mode you are in

Save this as `peerauthentication-migrate-demo-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: PERMISSIVE
```

Apply it:

```sh
kubectl apply -f peerauthentication-migrate-demo-permissive.yaml
```

This changes no behaviour. It makes the current mode visible, and it is the file you apply again if the switch goes wrong.

## Step 3: Inject a sidecar into outside-client

Sidecar injection happens only when a pod is created, so the label alone does nothing to the running pod:

```sh
kubectl label namespace outside istio-injection=enabled
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
```

```text
namespace/outside labeled
POD                               CONTAINERS       INIT
outside-client-5d765f547f-2q2t6   outside-client   <none>
```

One container and no init containers. Restart the Deployment so a new pod passes the injection webhook:

```sh
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
```

```text
deployment.apps/outside-client restarted
Waiting for deployment "outside-client" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "outside-client" rollout to finish: 1 old replicas are pending termination...
deployment "outside-client" successfully rolled out
POD                               CONTAINERS       INIT
outside-client-5d765f547f-2q2t6   outside-client   <none>
outside-client-66999dbd95-6dgsg   outside-client   istio-init,istio-proxy
```

The new pod carries `istio-proxy` in the `INIT` column. Istio 1.30 adds it as a native sidecar: an init container that keeps running beside the app, so `kubectl get pods` shows `2/2`. The old pod is still listed while it shuts down, which takes about 30 seconds. Wait until it is gone before you go on, or `kubectl exec deploy/outside-client` may still pick it.

## Step 4: Measure again

The old `none` requests stay in the counter. Send new requests from `outside-client` and run the counter pipeline from step 1 again:

```sh
for i in $(seq 1 5); do
  kubectl -n outside exec deploy/outside-client -- curl -s -o /dev/null -X POST http://notification-service.migrate-demo/notify
done
kubectl -n migrate-demo exec deploy/notification-service-v1 -c istio-proxy -- \
  pilot-agent request GET stats/prometheus \
  | grep '^istio_requests_total' | grep 'reporter="destination"' \
  | sed -n 's/.*connection_security_policy="\([^"]*\)".* \([0-9]*\)$/\1 \2/p' \
  | awk '{sum[$1]+=$2} END {for (k in sum) print k, sum[k]}'
```

```text
2026/10/09 07:29:00 INFO GOMEMLIMIT is already set, skipping package=github.com/KimMachineGun/automemlimit/memlimit GOMEMLIMIT=1073741824
mutual_tls 15
none 10
```

`mutual_tls` went up by 5, and `none` stopped going up. No plain-text requests arrive any more, so the switch is safe.

## Step 5: Switch to STRICT

Save this as `peerauthentication-migrate-demo-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-migrate-demo-strict.yaml
```

## Step 6: Prove it both ways

New configuration can take up to about a minute to reach connections that are already open. Wait a minute, then send real requests first:

```sh
kubectl -n migrate-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'in-mesh:  %{http_code}\n' -X POST http://notification-service/notify
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'migrated: %{http_code}\n' --max-time 5 -X POST http://notification-service.migrate-demo/notify
```

```text
in-mesh:  200
migrated: 200
```

Then ask `istiod`, Istio's control plane, which configuration applies to the `notification-service` pod:

```sh
NOTIFY_POD=$(kubectl -n migrate-demo get pod -l app=notification-service -o jsonpath='{.items[0].metadata.name}')
istioctl x describe pod "$NOTIFY_POD" -n migrate-demo
```

```text
Pod: notification-service-v1-54dd46d4b6-mpf7f
   Pod Revision: default
   Pod Ports: 8084 (notification-service)
--------------------
Service: notification-service
   Port: http 80/HTTP targets pod port 8084
--------------------
Effective PeerAuthentication:
   Workload mTLS mode: STRICT
Applied PeerAuthentication:
   default.migrate-demo
```

Traffic proves it works. The proxy's view proves the policy is the reason.

Now submit:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

---

## Common Mistakes

- **`outside-client` gets `000` (curl exit code 56).** It still sends plain text to a `STRICT` server. The namespace label was set, but the pod was never restarted.
- **`outside-client` shows `1/1`.** Same cause: run `kubectl -n outside rollout restart deployment outside-client`. Istio 1.30 adds `istio-proxy` as a native sidecar, so look for it among the init containers (or at `2/2` in the `READY` column), not only among the containers.
- **The `STRICT` check fails.** The policy has a `selector`, which makes it a workload policy, or it is not named `default`.
- **Testing too fast.** Right after a restart, `kubectl exec deploy/outside-client` can still reach the old pod without a sidecar. Wait for `rollout status` to report success.
