# Solution Walkthrough

Three policies at three scopes, and for each workload the narrowest one decides. The trick is that scope is not a field: the namespace an object lives in and whether it has a `selector` decide how far it reaches.

---

## Step 1: See the starting point

Check that no policy exists, and that the plain-text caller gets in:

```sh
kubectl get peerauthentication -A
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'outside -> notification: %{http_code}\n' \
  -X POST http://notification-service.mtls-demo/notify
```

```text
No resources found
outside -> notification: 200
```

No policy, and a caller without a sidecar gets `200`. That is the default mode, `PERMISSIVE`.

## Step 2: Make the whole mesh STRICT

A mesh-wide policy lives in the **root namespace**, `istio-system`, and has **no selector**.

Save this as `peerauthentication-mesh-default.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-mesh-default.yaml
```

```text
peerauthentication.security.istio.io/default created
```

Right now `outside-client` is refused by both services. The next policy opens the namespace again.

## Step 3: Give mtls-demo its exception

A namespace-wide policy lives in the namespace it covers, and has **no selector**.

Save this as `peerauthentication-mtls-demo-default.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mtls-demo
spec:
  mtls:
    mode: PERMISSIVE
```

Apply it:

```sh
kubectl apply -f peerauthentication-mtls-demo-default.yaml
```

```text
peerauthentication.security.istio.io/default created
```

The mesh policy still says `STRICT`. It no longer decides anything in `mtls-demo`, because the namespace policy is narrower.

## Step 4: Make notification-service STRICT again

A workload policy lives in the namespace of the pods, and **has a selector** that matches their labels.

Save this as `peerauthentication-notification-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: notification-strict
  namespace: mtls-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-notification-strict.yaml
```

```text
peerauthentication.security.istio.io/notification-strict created
```

## Step 5: Prove all three

List the policies:

```sh
kubectl get peerauthentication -A
```

```text
NAMESPACE      NAME                  MODE         AGE
istio-system   default               STRICT       0s
mtls-demo      default               PERMISSIVE   0s
mtls-demo      notification-strict   STRICT       0s
```

Then send the three requests the task asks for. A new policy can take up to a minute to reach every proxy, so if a result looks old, wait and send it again:

```sh
kubectl -n outside exec deploy/outside-client -- sh -c \
  'curl -s -o /dev/null -w "notification: %{http_code}\n" --max-time 5 -X POST http://notification-service.mtls-demo/notify;
   curl -s -o /dev/null -w "booking:      %{http_code}\n" --max-time 5 -X POST http://booking-service.mtls-demo/book'
kubectl -n mtls-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'in-mesh:      %{http_code}\n' -X POST http://notification-service/notify
```

```text
notification: 000
booking:      200
in-mesh:      200
```

Two workloads in one namespace, one shared namespace policy, and two different answers. `notification-service` is covered by something narrower.

You can also ask the pod which policy won:

```sh
istioctl x describe pod $(kubectl -n mtls-demo get pod -l app=notification-service -o jsonpath='{.items[0].metadata.name}') -n mtls-demo
```

```text
Pod: notification-service-v1-54dd46d4b6-pbhzn
   Pod Revision: default
   Pod Ports: 8084 (notification-service)
--------------------
Service: notification-service
   Port: http 80/HTTP targets pod port 8084
--------------------
Effective PeerAuthentication:
   Workload mTLS mode: STRICT
Applied PeerAuthentication:
   default.istio-system, default.mtls-demo, notification-strict.mtls-demo
Skipping Gateway information (no ingress gateway pods)
```

**Workload mTLS mode** is the result: `STRICT`. **Applied PeerAuthentication** lists all three policies, because all three cover this pod. The narrowest one, `notification-strict.mtls-demo`, is the one that decided.

Now submit:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

---

## Common Mistakes

- **The mesh-wide policy in `mtls-demo`.** It is then just a second namespace policy, and nothing is mesh-wide. Only `istio-system` makes a policy mesh-wide.
- **A selector on the namespace exception.** It becomes a workload policy and covers far less than the namespace.
- **`outside-client` still reaches `notification-service`.** The workload policy's selector does not match the pods. Compare it with `kubectl -n mtls-demo get pods --show-labels`.
- **`outside-client` cannot reach `booking-service` either.** The namespace exception is missing, or it was saved in the wrong namespace.
- **Testing too fast.** `kubectl apply` returns before the proxies have the new configuration. If a result looks old, wait up to a minute and send the request again.
