# Solution Walkthrough

Mission debrief, astronaut. You close the planet first, then open two narrow doors, and finally put the admin door on the banned list. The banned list is checked before any guest list, so nothing you add later can open that door.

---

## Step 1: Close the planet

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

Then check the result:

```sh
kubectl -n authz-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester POST /book: %{http_code}\n' -X POST http://booking-service/book
```

<!-- OUTPUT PENDING: expect "tester POST /book: 403" -->

An empty `spec` reads like this. No `action` means `ALLOW`. No `selector` means every workload in the namespace. No `rules` means nothing matches. So every ship is on a guest list with no names, and every signal is turned away.

Keep this object for good. It is what makes a service deployed next week start closed instead of open.

---

## Step 2: Reopen the booking door

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

The caller (`from`) and the method and path (`to`) sit in the same rule, so a request must match all of them. A `GET /book` from the same caller is still refused.

---

## Step 3: Reopen the notification door, by identity

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

A `namespaces` match would not work here. `tester` lives in `authz-demo` too, so only the name on the ID badge tells the two callers apart.

---

## Step 4: The backstop, and the proof

Two objects go in one file: the banned list, and your colleague's careless future guest list, written today.

Save this as `authorizationpolicy-admin.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-admin.yaml
```

For each request, the communications officer checks `CUSTOM`, then `DENY`, then `ALLOW`. A match on the banned list ends the decision, so the guest list for `/admin` is never read.

The path is `/admin*`, not `/admin`. An exact path would leave `/admin/users` open, and a test of `/admin` alone would still look like a success.

---

## Step 5: Prove all six calls

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

Every `403` here comes from the guard at the airlock. A `404` on an `/admin` line would mean the request got past every rule and reached the app.

Now submit:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

---

## Common Mistakes

- **`/admin` returns `404`.** Nothing blocked it, so the request reached the app. The `DENY` policy is missing, or its selector matches no pod.
- **`/admin/users` returns `404` while `/admin` returns `403`.** The path has no `*`, so it matches only the exact path.
- **Making the backstop an `ALLOW` policy.** More guest lists never take anyone off. Only a `DENY` policy can be a backstop.
- **Deleting `allow-admin-attempt` to make things pass.** The grader checks that it is still there.
- **booking-service gets `403` on `/notify`.** The principal is wrong. Check the namespace and service account, and drop any `spiffe://` prefix.
