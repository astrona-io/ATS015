# Step-by-Step Guide: CAP015-010

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Measure first

```sh
kubectl -n outside exec deploy/outside-client -- sh -c \
  'for i in $(seq 1 5); do curl -s -o /dev/null -X POST http://booking-service.identity-demo/book; done'
kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
  pilot-agent request GET stats/prometheus 2>/dev/null | grep istio_requests_total \
  | grep -o 'connection_security_policy="[^"]*"' | sort | uniq -c
```

`none` in that output is the reason you cannot start with step 3.

## Step 2: Migrate the unmeshed caller

Injection is an admission webhook that runs at pod creation, so the label alone
does nothing to a running pod:

```sh
kubectl label namespace outside istio-injection=enabled
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                              CONTAINERS
outside-client-6c4b8d9f7-vt2km   outside-client,istio-proxy
```

Two containers. This is the disruptive step, and it is deliberately first.

## Step 3: Mesh-wide STRICT

Mesh scope means the **root namespace** and **no selector**:

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

kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'outside -> booking: %{http_code}\n' --max-time 5 \
  -X POST http://booking-service.identity-demo/book
```

```text
outside -> booking: 200
```

Still `200`, because step 2 happened first. Had you flipped this before
migrating, it would read `000`.

## Step 4: Read the identity

```sh
istioctl proxy-config secret deploy/booking-service-v1 -n identity-demo -o json \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin); \
      c=[s for s in d['dynamicActiveSecrets'] if s['name']=='default'][0]; \
      print(base64.b64decode(c['secret']['tlsCertificate']['certificateChain']['inlineBytes']).decode())" \
  > /tmp/workload.crt
openssl x509 -in /tmp/workload.crt -noout -text | grep -A1 'Subject Alternative Name'
```

```text
                URI:spiffe://cluster.local/ns/identity-demo/sa/booking-sa
```

The policy field takes the same value without the scheme.

## Step 5: Authorize on it

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-by-identity
  namespace: identity-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/identity-demo/sa/booking-sa
YAML
```

`tester` runs as `default`, so naming the namespace would have let it through.

## Step 6: Prove all three

```sh
kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w 'booking -> notify: %{http_code}\n' -X POST http://notification-service/notify
kubectl -n identity-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester  -> notify: %{http_code}\n' -X POST http://notification-service/notify
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'outside -> book:   %{http_code}\n' --max-time 5 -X POST http://booking-service.identity-demo/book
```

```text
booking -> notify: 200
tester  -> notify: 403
outside -> book:   200
```

Note the two kinds of success and one kind of failure — and that the failure is a
`403` (authorization) rather than `000` (transport).

## Step 7: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`outside-client` gets `000`.** It is still unmeshed, or the mesh policy was
  applied before the restart completed.
- **`booking-service` gets `403`.** The principal is wrong — most often a
  leftover `spiffe://`.
- **The mesh check fails.** The `PeerAuthentication` is in `identity-demo`
  instead of `istio-system`, which makes it a namespace policy.
