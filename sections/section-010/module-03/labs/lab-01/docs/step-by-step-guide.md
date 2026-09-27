# Step-by-Step Guide: LAB015-010-03

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Measure, before changing anything

Generate traffic from both callers, then read the receiving proxy's counters:

```sh
kubectl -n migrate-demo exec deploy/tester -- sh -c \
  'for i in $(seq 1 10); do curl -s -o /dev/null -X POST http://notification-service/notify; done'
kubectl -n outside exec deploy/outside-client -- sh -c \
  'for i in $(seq 1 10); do curl -s -o /dev/null -X POST http://notification-service.migrate-demo/notify; done'

kubectl -n migrate-demo exec deploy/notification-service-v1 -c istio-proxy -- \
  pilot-agent request GET stats/prometheus | grep istio_requests_total \
  | grep -o 'connection_security_policy="[^"]*"' | sort | uniq -c
```

```text
  10 connection_security_policy="mutual_tls"
  10 connection_security_policy="none"
```

`none` is present, so flipping to `STRICT` right now would break a caller. Note
`-c istio-proxy` — the counter lives in the sidecar, not the application.

## Step 2: Declare the state you are in (and your rollback)

```sh
cat > /tmp/permissive.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: PERMISSIVE
YAML
kubectl apply -f /tmp/permissive.yaml
```

This changes no behaviour. It makes the current mode reviewable, and it is the
file you re-apply if the flip goes wrong.

## Step 3: Mesh the remaining caller

Injection is done by an admission webhook **at pod creation**, so the label alone
does nothing to a running pod:

```sh
kubectl label namespace outside istio-injection=enabled
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                              CONTAINERS
outside-client-8f9d7c6b5-n4xqr   outside-client
```

One container. The pod has to be replaced:

```sh
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                              CONTAINERS
outside-client-6c4b8d9f7-vt2km   outside-client,istio-proxy
```

This restart is the disruptive part of a real migration.

## Step 4: Re-measure

Counters are cumulative, so the old `none` samples are still in the total. Send
fresh traffic and confirm the `none` count stops *increasing* — that, not zero,
is the signal.

## Step 5: Enforce

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: STRICT
YAML
```

## Step 6: Verify, both ways

```sh
kubectl -n migrate-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'in-mesh:  %{http_code}\n' -X POST http://notification-service/notify
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'migrated: %{http_code}\n' --max-time 5 -X POST http://notification-service.migrate-demo/notify

istioctl proxy-config listener deploy/notification-service-v1 -n migrate-demo \
  --port 8084 -o json | grep -i requireClientCertificate
```

```text
in-mesh:  200
migrated: 200
    "requireClientCertificate": true,
```

Traffic proves it works; the listener proves the policy is the reason.

## Step 7: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`outside-client` gets `000`.** It is still unmeshed. The namespace label was
  applied but the pod was never recreated.
- **`outside-client` has one container.** Same cause — `rollout restart`.
- **The STRICT check fails.** The policy may carry a `selector`, which makes it a
  workload policy rather than a namespace one.
