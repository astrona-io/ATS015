# Step-by-Step Guide: CAP015-020

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Close the namespace

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: authz-demo
spec: {}
YAML
```

No `action` means `ALLOW`; no `selector` means every workload in the namespace;
no `rules` means nothing matches. Every workload here is now selected by an
`ALLOW` policy and must match a rule — and there are none.

Keep this object for good. It is what makes a service deployed next week start
closed instead of open.

## Step 2: Reopen the booking call

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: booking-allow
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: booking-service
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces: ["authz-demo"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/book"]
YAML
```

Method and path in the same rule as the caller — all present parts must match.

## Step 3: Reopen the notification call, by identity

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-allow
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/authz-demo/sa/booking-sa
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
YAML
```

`namespaces` would not work here — `tester` is in `authz-demo` too.

## Step 4: The backstop, and the proof

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-admin
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: DENY
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-admin-attempt
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
YAML
```

The second object is your colleague's careless future rule, written today. For
each request the proxy walks `CUSTOM` → `DENY` → `ALLOW`, and a match in the
`DENY` group ends the decision — so it is never read.

`/admin*` rather than `/admin`: an exact path would leave `/admin/users` open,
and testing only `/admin` would report success.

## Step 5: Prove all six

```sh
kubectl -n authz-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "tester POST /book:         %{http_code}\n" -X POST http://booking-service/book;
   curl -s -o /dev/null -w "tester GET  /book:         %{http_code}\n" -X GET  http://booking-service/book;
   curl -s -o /dev/null -w "tester POST /notify:       %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "tester GET  /admin:        %{http_code}\n" http://notification-service/admin;
   curl -s -o /dev/null -w "tester GET  /admin/users:  %{http_code}\n" http://notification-service/admin/users'
kubectl -n authz-demo exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w 'booking POST /notify:      %{http_code}\n' -X POST http://notification-service/notify
```

```text
tester POST /book:         200
tester GET  /book:         403
tester POST /notify:       403
tester GET  /admin:        403
tester GET  /admin/users:  403
booking POST /notify:      200
```

## Step 6: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`/admin` returns `404`.** Nothing blocked it — the request reached the
  application. The `DENY` is missing or its selector matches no pod.
- **`/admin/users` returns `404` while `/admin` is `403`.** The path has no `*`.
- **`booking-service` is refused on `/notify`.** The principal string is wrong.
