# Solution Walkthrough

mTLS proved who was calling, but no policy checked the identities. You close the namespace with one allow-nothing policy, then add two narrow `ALLOW` policies: one for the whole namespace, one for a single identity.

---

## Step 1: Confirm the starting point

Check that no policy exists, and that the tester can call the notification service directly:

```sh
kubectl -n authz-demo get authorizationpolicy
kubectl -n authz-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester -> notify: %{http_code}\n' -X POST http://notification-service/notify
```

```text
No resources found in authz-demo namespace.
tester -> notify: 200
```

No policy means every request that passes mTLS gets in. mTLS is on and `STRICT`, but it does not answer the question "may this caller do this?".

## Step 2: Close the namespace

Save this as `authorizationpolicy-allow-nothing.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: authz-demo
spec: {}
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-allow-nothing.yaml
```

Three fields are left out, and each one does part of the work. No `action` means `ALLOW`. No `selector` means every workload in the namespace. No `rules` means no call can match. So every workload here is now selected by an `ALLOW` policy, and the policy allows nothing.

Wait up to about a minute, then check the result:

```sh
kubectl -n authz-demo exec deploy/tester -- \
  curl -s -w '\n' -X POST http://booking-service/book
```

```text
RBAC: access denied
```

Look at the shape: a complete HTTP response with a short body. That is the receiving proxy's RBAC filter denying the call, not mTLS cutting the connection.

## Step 3: Reopen the booking call for the namespace

Save this as `authorizationpolicy-booking-allow.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-booking-allow.yaml
```

Read it as one sentence: *on the booking workloads, allow a caller from namespace `authz-demo` to `POST` `/book`*. Because `allow-nothing` is still there, nothing else gets in.

This policy did not replace `allow-nothing`. Both select `booking-service`, and a call gets in when it matches a rule in either policy.

## Step 4: Reopen the notification call, by identity

Save this as `authorizationpolicy-notification-allow.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-notification-allow.yaml
```

`namespaces` would not work here: `tester` lives in `authz-demo` too. The principal is `<trust domain>/ns/<namespace>/sa/<service account>`, written without the `spiffe://` prefix.

## Step 5: Prove all five results

Wait up to about a minute, so connections opened before your changes are closed. Then send all five calls:

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

Two of the `403` answers are about the **method**, not the caller. That proves the `to` part of each rule is doing its job.

Now submit:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

---

## Common Mistakes

- **Everything is `403`, including `booking-service`.** The principal string is wrong, most often because of a leftover `spiffe://` prefix or a wrong service account name.
- **`tester` reaches `/notify`.** The rule matches on `namespaces` instead of `principals`. `tester` lives in `authz-demo` too.
- **`GET` is allowed.** The rule has a `from` but no `to`, so it allows any operation. A part you leave out is a wildcard, not a limit.
- **Testing too fast.** A connection opened before your change can keep the old rules for a short while. If you see a mix of results, wait and send the calls again.
