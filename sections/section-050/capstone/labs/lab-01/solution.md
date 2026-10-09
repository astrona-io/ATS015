# Solution Walkthrough

Mission debrief, astronaut. Both wishes are banned lists. One bans a range of return addresses everywhere. The other bans the admin path for everyone outside the office range. A guest list would have closed every hostname on this shared gate.

---

## Step 1: Confirm the gate trusts one relay station

Read the gateway's live listener configuration and look for the number of trusted hops:

```sh
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system -o json \
  | grep -m1 -o '"xffNumTrustedHops": *[0-9]*'
```

<!-- OUTPUT PENDING: expect "xffNumTrustedHops": 1 -->

With one trusted hop, the gateway counts back one entry in `X-Forwarded-For` and treats that address as the client. Without it, the rules below would match the wrong address.

---

## Step 2: The global block-list

Save this as `authorizationpolicy-gateway-block-list.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-block-list
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: DENY
  rules:
    - from:
        - source:
            remoteIpBlocks:
              - 192.168.0.0/16
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-block-list.yaml
```

It is a `DENY`, because a block-list takes callers away. An `ALLOW` with nothing else on the gate would close every hostname this shared gateway serves.

It uses `remoteIpBlocks`, not `ipBlocks`. `ipBlocks` matches whoever opened the connection, and behind a relay station that is the relay station.

---

## Step 3: The office-only admin path

"Deny `/admin*` unless the client is in the office range" is one `DENY` rule with a reversed source condition.

Save this as `authorizationpolicy-gateway-admin-office-only.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-admin-office-only
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: DENY
  rules:
    - from:
        - source:
            notRemoteIpBlocks:
              - 203.0.113.0/24
      to:
        - operation:
            paths: ["/admin*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-admin-office-only.yaml
```

Read it aloud, starting with the action: *deny requests whose client is **not** in 203.0.113.0/24 **and** whose path is `/admin*`.* Both parts of the rule must match. The `to` block is what keeps the ban on the admin paths only. Without it, this rule would deny the whole internet.

The path is `/admin*`, not `/admin`, so `/admin/users` is covered too.

---

## Step 4: Prove all five requests

Open a port-forward to the gate. Then a small helper sends one request with a chosen return address in `X-Forwarded-For`:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
sleep 2
send_signal() { curl -s -o /dev/null -w "$1 $2: %{http_code}\n" \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: $1" "http://localhost:8080$2"; }
send_signal 10.1.2.3    /book
send_signal 192.168.5.5 /book
send_signal 10.1.2.3    /admin
send_signal 203.0.113.9 /admin
send_signal 192.168.5.5 /admin
```

```text
10.1.2.3 /book: 200
192.168.5.5 /book: 403
10.1.2.3 /admin: 403
203.0.113.9 /admin: 404
192.168.5.5 /admin: 403
```

The `404` is the pass: that request was let through, and the app has no such page. Look at the last line too. The two rules overlap there, and a request caught by either one is denied. Both are banned lists, and any match on a banned list ends the decision.

Stop the port-forward with `kill %1`.

Now submit:

```sh
astrona submit -c sections/section-050/capstone/labs/lab-01
```

---

## Common Mistakes

- **Every request returns `403`.** The admin rule probably has no `to` block, so it denies every path for every client outside the office range.
- **`/admin` is reachable from `10.1.2.3`.** The condition is not reversed: you wrote `remoteIpBlocks` where `notRemoteIpBlocks` was needed.
- **Nothing is blocked at all.** The policies are in the wrong namespace, or the selector does not match the gateway pod.
- **Using `ipBlocks`.** It matches the port-forward's address, never the address in `X-Forwarded-For`.
- **Writing an `ALLOW` for the office range.** On a shared gate, that closes every other hostname and path to everyone else.
