# Step-by-Step Guide: LAB015-020-02

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: The ALLOW baseline

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-notify
  namespace: deny-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces: ["deny-demo"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
YAML

kubectl -n deny-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "GET  /admin:  %{http_code}\n" http://notification-service/admin'
```

```text
POST /notify: 200
GET  /admin:  403
```

`/admin` is already refused — and nobody denied it. An `ALLOW` policy now selects
this workload, `/admin` matches none of its rules, and that is enough. Keep this
in mind: the `DENY` you add next produces an identical `403` for a completely
different reason.

## Step 2: The DENY

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-admin
  namespace: deny-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: DENY
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
YAML
```

The `*` matters. `paths: ["/admin"]` matches that exact path and leaves
`/admin/users` reachable — a hole that reports as working, because the URL you
tested is blocked.

The rule has no `from`, so it matches any caller. Under `DENY`, an omitted part
is sweeping rather than generous, which is what you want here.

## Step 3: The conflicting ALLOW

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-admin-attempt
  namespace: deny-demo
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

## Step 4: Watch it change nothing

```sh
kubectl -n deny-demo get authorizationpolicy
kubectl -n deny-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "POST /notify:      %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "GET  /admin:       %{http_code}\n" http://notification-service/admin;
   curl -s -o /dev/null -w "GET  /admin/users: %{http_code}\n" http://notification-service/admin/users'
```

```text
NAME                  AGE
allow-admin-attempt   5s
allow-notify          3m
deny-admin            1m
POST /notify:      200
GET  /admin:       403
GET  /admin/users: 403
```

Three policies, one of which explicitly allows exactly this request, and it is
still refused. For each request the proxy walks `CUSTOM` → `DENY` → `ALLOW`, and
a match in the `DENY` group **ends** the decision — `allow-admin-attempt` is
never read.

That is why you cannot carve an exception out of a `DENY` by adding an `ALLOW`.
If `/admin/health` needed to be reachable, the exception would have to be written
into the `DENY` itself.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`/admin` returns `404`.** Nothing is blocking it: the request reached the
  application. Your `DENY` is missing, or its selector matches no pod.
- **`/admin` is `403` but `/admin/users` is `404`.** The path has no `*`.
- **`/notify` is `403`.** The `DENY` is too wide — check that its path rule is
  not something like `notPaths: ["/notify"]`.
