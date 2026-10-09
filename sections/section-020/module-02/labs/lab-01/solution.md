# Solution Walkthrough

You need three policies on one workload: an `ALLOW` policy for the normal call, a `DENY` policy for the admin area, and a careless `ALLOW` policy that proves the `DENY` holds. The sidecar proxy checks `DENY` policies first, so the third policy can never reopen the admin path.

---

## Step 1: The ALLOW policy for the normal call

Start with the `ALLOW` policy for `POST /notify`.

Save this as `authorizationpolicy-allow-notify.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-allow-notify.yaml
```

Wait up to about a minute, then check the result:

```sh
kubectl -n deny-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "GET  /admin:  %{http_code}\n" http://notification-service/admin'
```

```text
POST /notify: 200
GET  /admin:  403
```

`/admin` is already refused, and nobody banned it. An `ALLOW` policy now selects this workload, and `/admin` fits none of its rules, so the sidecar proxy's last step says no. The `DENY` you add next gives the same `403` for a different reason.

## Step 2: The DENY policy

Save this as `authorizationpolicy-deny-admin.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-deny-admin.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/deny-admin created
```

The warning is normal. A rule with only HTTP fields such as `paths` cannot be checked on a plain TCP port, so the sidecar proxy blocks such ports on this workload completely. The notification service only speaks HTTP, so nothing breaks.

The `*` matters. `paths: ["/admin"]` matches only that exact path and leaves `/admin/users` open. That gap is easy to miss, because the path you tested is blocked.

The rule has no `from`, so it covers every caller. Under `DENY`, a missing part matches everything, which is what you want here.

## Step 3: The careless ALLOW policy

Save this as `authorizationpolicy-allow-admin-attempt.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-allow-admin-attempt.yaml
```

## Step 4: Watch it change nothing

Wait up to about a minute, then list the policies and send all three requests:

```sh
kubectl -n deny-demo get authorizationpolicy
kubectl -n deny-demo exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "POST /notify:      %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "GET  /admin:       %{http_code}\n" http://notification-service/admin;
   curl -s -o /dev/null -w "GET  /admin/users: %{http_code}\n" http://notification-service/admin/users'
```

```text
NAME                  ACTION   AGE
allow-admin-attempt   ALLOW    60s
allow-notify          ALLOW    2m1s
deny-admin            DENY     60s
POST /notify:      200
GET  /admin:       403
GET  /admin/users: 403
```

Three policies, and one of them explicitly allows `/admin`. It is still refused. For each request the sidecar proxy walks `CUSTOM`, then `DENY`, then `ALLOW`, and a `DENY` match **ends** the decision. `allow-admin-attempt` is never checked.

That is why you cannot cut an exception out of a `DENY` with an `ALLOW`. If `/admin/health` had to stay reachable, the exception would have to go into the `DENY` itself, for example with `notPaths`.

Now submit:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

---

## Common Mistakes

- **`/admin` returns `200`.** Nothing blocks it: the request reached the app. Your `DENY` is missing, or its `selector` matches no pod. Check `app: notification-service`.
- **`/admin` is `403` but `/admin/users` is `200`.** The path has no `*`, so only the exact path is banned.
- **`/notify` is `403`.** Either the `ALLOW` for `/notify` is missing, or the `DENY` is too wide. Check that it has no negative field such as `notPaths: ["/notify"]`.
- **Deleting `allow-admin-attempt` to make things pass.** The grader checks that an `ALLOW` naming `/admin` still exists.
- **Testing too fast.** Old connections keep the old rules for a while. If results look mixed, wait up to about a minute and try again.
