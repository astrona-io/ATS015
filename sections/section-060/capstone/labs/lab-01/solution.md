# Solution Walkthrough

Mission debrief, astronaut. The rule reads the letter (method and path), so a relay tower cannot enforce it. You write the rule for the waypoint, build the waypoint, and send the traffic through it. Until the last step, the rule exists and does nothing.

---

## Step 1: Confirm the starting point

Ask the relay towers which ships they carry, and look for a waypoint:

```sh
istioctl ztunnel-config workload --namespace ambient-authz
kubectl -n ambient-authz get gateway
```

<!-- OUTPUT PENDING: workload table with PROTOCOL HBONE and WAYPOINT None for each pod; then "No resources found in ambient-authz namespace." -->

`HBONE` on each workload means a relay tower carries its traffic through the sealed tunnel and does the handshake for it. `None` in the waypoint column and no `Gateway` mean there is nobody yet who can read a signal's contents.

---

## Step 2: Write the rule for the waypoint

Save this as `authorizationpolicy-notification-l7.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-notification-l7.yaml
```

Then check the result:

```sh
kubectl -n ambient-authz exec deploy/tester -- \
  curl -s -o /dev/null -w 'GET (should be blocked): %{http_code}\n' -X GET http://notification-service/notify
```

<!-- OUTPUT PENDING: expect "GET (should be blocked): 200" (no waypoint yet, so nothing enforces the rule) -->

Accepted, listed, and ignored. `targetRefs` points the rule at the waypoint in front of `notification-service`, and there is no waypoint yet. The relay tower cannot see that this was a `GET`. This is the ambient trap.

---

## Step 3: Build the waypoint and send traffic through it

```sh
istioctl waypoint apply -n ambient-authz --enroll-namespace --wait
kubectl -n ambient-authz get gateway
kubectl get namespace ambient-authz --show-labels
```

<!-- OUTPUT PENDING: waypoint created and namespace labelled; gateway "waypoint" with CLASS istio-waypoint and PROGRAMMED True; namespace labels include istio.io/dataplane-mode=ambient and istio.io/use-waypoint=waypoint -->

Two separate things happened. The waypoint was created, and the `--enroll-namespace` flag added the `istio.io/use-waypoint=waypoint` label, so traffic now goes through it. A waypoint without that label shows `PROGRAMMED` `True` and receives nothing.

---

## Step 4: Prove all four requests

```sh
kubectl -n ambient-authz exec deploy/other-client -- \
  curl -s -o /dev/null -w 'other  POST /notify: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
kubectl -n ambient-authz exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "tester POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "tester GET  /notify: %{http_code}\n" -X GET  http://notification-service/notify;
   curl -s -o /dev/null -w "tester POST /admin:  %{http_code}\n" -X POST http://notification-service/admin'
```

<!-- OUTPUT PENDING: expect other POST /notify 403, tester POST /notify 200, tester GET /notify 403, tester POST /admin 403 -->

Every refusal is a `403` from the waypoint. It reads both the ID badge (`other-client` has the wrong one) and the letter (`GET` and `/admin` are not allowed).

---

## Step 5: Show which component holds the rule

```sh
istioctl ztunnel-config policy --namespace ambient-authz
istioctl proxy-config listener deploy/waypoint -n ambient-authz -o json | grep -i rbac | head
```

<!-- OUTPUT PENDING: ztunnel policy list (expect no entry for notification-l7); then RBAC filter lines from the waypoint listener -->

The relay towers do not hold `notification-l7`. The waypoint does. A policy that shows up in `kubectl get` but in neither place is a policy that nothing enforces.

You did not write a second rule with a label `selector` for the relay towers. With the waypoint in the path, the notification pod sees signals arriving from the waypoint, with the waypoint's ID badge. A selector rule that names `tester-sa` would refuse the waypoint itself, and nobody would get through.

Now submit:

```sh
astrona submit -c sections/section-060/capstone/labs/lab-01
```

---

## Common Mistakes

- **`GET` returns `200`.** There is no waypoint, it was never enrolled, or the policy uses a `selector` instead of `targetRefs`.
- **`other-client` gets `000`.** Its connection was dropped before any HTTP answer, so the waypoint is not in the path, or an extra rule refuses connections.
- **Every call fails, even `tester POST /notify`.** A selector rule on the notification pod is refusing the waypoint's own identity. Delete it.
- **Waypoint created but not enrolled.** Creating the station and sending traffic through it are two steps. Check for the `istio.io/use-waypoint` label.
- **Using `istioctl proxy-config` on an application pod.** In ambient mode there is no sidecar there. Use `istioctl ztunnel-config`, or `proxy-config` on the waypoint.
