# Step-by-Step Guide: LAB015-020-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Confirm the starting point

```sh
kubectl -n authz-demo get authorizationpolicy
kubectl -n authz-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester -> notify: %{http_code}\n' -X POST http://notification-service/notify
```

```text
No resources found in authz-demo namespace.
tester -> notify: 200
```

No policy means everything is allowed. mTLS is on and strict; it simply does not
answer this question.

## Step 2: Close the namespace

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

Three omissions doing the work: no `action` means `ALLOW`, no `selector` means
every workload in the namespace, no `rules` means nothing can match. So every
workload here is now selected by an `ALLOW` policy and must match a rule — and
there are none.

```sh
kubectl -n authz-demo exec deploy/tester -- \
  curl -s -w '\n' -X POST http://booking-service/book
```

```text
RBAC: access denied
```

Note the shape: a complete HTTP response with a body. That is an authorization
denial, not a transport rejection.

## Step 3: Reopen the booking call

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

Read it as one sentence: *on the booking workloads, allow a caller from namespace
`authz-demo` to POST `/book`* — and, because of the baseline, nothing else.

This did not replace `allow-nothing`. Both select `booking-service`, and the
request is allowed because it matched a rule in one of them.

## Step 4: Reopen the notification call, by identity

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

`namespaces` would not do here — `tester` is in the same namespace. The principal
format is `<trust-domain>/ns/<namespace>/sa/<service-account>`, with no
`spiffe://` prefix.

## Step 5: Prove all five outcomes

```sh
kubectl -n authz-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "tester POST /book:    %{http_code}\n" -X POST http://booking-service/book;
   curl -s -o /dev/null -w "tester GET  /book:    %{http_code}\n" -X GET  http://booking-service/book;
   curl -s -o /dev/null -w "tester POST /notify:  %{http_code}\n" -X POST http://notification-service/notify'
kubectl -n authz-demo exec deploy/booking-service-v1 -c booking-service -- sh -c \
  'curl -s -o /dev/null -w "booking POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "booking GET  /notify: %{http_code}\n" -X GET  http://notification-service/notify'
```

```text
tester POST /book:    200
tester GET  /book:    403
tester POST /notify:  403
booking POST /notify: 200
booking GET  /notify: 403
```

## Step 6: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Everything is `403`, including `booking-service`.** The principal string is
  wrong — most often a leftover `spiffe://` prefix.
- **`tester` reaches `/notify`.** The rule matches on `namespaces` rather than
  `principals`; `tester` is in `authz-demo` too.
- **`GET` is allowed.** The rule has a `from` but no `to`, so it permits any
  operation. An omitted part is a wildcard, not a restriction.
