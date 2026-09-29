# Step-by-Step Guide: CAP015-060

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Confirm the starting point

```sh
istioctl ztunnel-config workload --namespace ambient-authz
kubectl -n ambient-authz get gateway
```

`PROTOCOL: HBONE` on each workload means ztunnel is carrying the traffic and
doing mTLS for it. `WAYPOINT: None` and an empty gateway list mean there is no
L7 layer yet.

## Step 2: The connection-level half

Identity is read from the peer certificate on the HBONE connection, so ztunnel
can enforce this with no waypoint:

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > authorizationpolicy-notification-l4.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-l4
  namespace: ambient-authz
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/ambient-authz/sa/tester-sa
YAML
kubectl apply -f authorizationpolicy-notification-l4.yaml

sleep 3
kubectl -n ambient-authz exec deploy/other-client -- \
  curl -s -o /dev/null -w 'other-client: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
```

```text
other-client: 000
```

A label `selector` is the right attachment here, and `000` rather than `403` is
the signature: ztunnel has no HTTP layer, so it refuses the connection.

## Step 3: The request-level half

```sh
cat > authorizationpolicy-notification-l7.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-l7
  namespace: ambient-authz
spec:
  targetRefs:
    - kind: Service
      group: ""
      name: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/ambient-authz/sa/tester-sa
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
YAML
kubectl apply -f authorizationpolicy-notification-l7.yaml

sleep 3
kubectl -n ambient-authz exec deploy/tester -- \
  curl -s -o /dev/null -w 'GET (should be blocked): %{http_code}\n' -X GET http://notification-service/notify
```

```text
GET (should be blocked): 200
```

Accepted, listed, and ignored. Nothing in the path can see that this was a `GET`.
This is the ambient trap, and the reason step 4 exists.

## Step 4: Deploy and enrol a waypoint

```sh
istioctl waypoint apply -n ambient-authz --enroll-namespace
kubectl -n ambient-authz rollout status deployment waypoint
kubectl -n ambient-authz get gateway
```

```text
NAME       CLASS            ADDRESS      PROGRAMMED
waypoint   istio-waypoint   10.96.x.x    True
```

Two separate things happened: the waypoint was created, and the namespace was
enrolled so traffic goes through it. A waypoint without enrolment reports
`PROGRAMMED: True` and receives nothing.

## Step 5: Prove all four

```sh
kubectl -n ambient-authz exec deploy/other-client -- \
  curl -s -o /dev/null -w 'other POST /notify: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
kubectl -n ambient-authz exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "tester POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "tester GET  /notify: %{http_code}\n" -X GET  http://notification-service/notify;
   curl -s -o /dev/null -w "tester POST /admin:  %{http_code}\n" -X POST http://notification-service/admin'
```

```text
other POST /notify: 000
tester POST /notify: 200
tester GET  /notify: 403
tester POST /admin:  403
```

Two failure shapes from two components: `000` from ztunnel at the connection,
`403` from the waypoint at the request.

## Step 6: Show which component holds which

```sh
istioctl ztunnel-config policy --namespace ambient-authz
kubectl -n ambient-authz get authorizationpolicy
istioctl proxy-config listener deploy/waypoint -n ambient-authz -o json | grep -i rbac | head
```

ztunnel lists only the L4 policy; the L7 one is on the waypoint. A policy in
`kubectl get` and in neither place is a policy nothing enforces.

## Step 7: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`GET` returns `200`.** No waypoint, or it was never enrolled, or the L7
  policy uses a `selector` instead of `targetRefs`.
- **`other-client` gets `403`.** Its traffic is being refused at L7 rather than
  at the connection — the identity rule needs to be the L4 one.
- **`tester` gets `000`.** The principal string is wrong; check the service
  account name.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/) — the SPIFFE identity format and where it comes from
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [Ambient mode](https://istio.io/latest/docs/ambient/usage/l4-policy/) — what changes for policy without a sidecar
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
