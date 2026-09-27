# Step-by-Step Guide: LAB015-010-02

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 0: See the starting point

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

No policy, and a plaintext caller succeeding. That is `PERMISSIVE` by default.

## Step 1: Mesh-wide STRICT

Mesh scope means the **root namespace** (`istio-system`) and **no selector**:

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
YAML
```

Check it took effect before moving on — `outside-client` should now be refused
by both services.

## Step 2: The namespace exception

Namespace scope means the target namespace and **no selector**:

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mtls-demo
spec:
  mtls:
    mode: PERMISSIVE
YAML
```

The mesh policy is untouched and still says `STRICT`. It simply no longer decides
anything in `mtls-demo`, because narrowest wins.

## Step 3: The workload override

Workload scope means the target namespace **plus a selector**:

```sh
kubectl apply -f - <<'YAML'
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
YAML
```

## Step 4: Prove all three

```sh
kubectl get peerauthentication -A
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

Two workloads, one namespace, one shared namespace policy — behaving differently
because one of them is covered by something narrower.

You can also read the decision off the proxy rather than inferring it:

```sh
istioctl proxy-config listener deploy/notification-service-v1 -n mtls-demo \
  --port 8084 -o json | grep -i requireClientCertificate
```

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`outside-client` reaches `notification-service`.** The workload policy is not
  applying. Check the selector against
  `kubectl -n mtls-demo get pods --show-labels`.
- **`outside-client` cannot reach `booking-service` either.** Your namespace
  exception is missing, or it was created in the wrong namespace.
- **Nothing changed at all.** The mesh-wide policy probably went into `mtls-demo`
  instead of `istio-system`, where it is just another namespace policy.
