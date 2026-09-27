# Step-by-Step Guide: CAP015-050

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Confirm the topology setting

```sh
kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' | grep -A2 gatewayTopology
```

```text
gatewayTopology:
  numTrustedProxies: 1
```

With one trusted hop, the gateway counts back one entry in `X-Forwarded-For` and
treats that as the client. Without it, everything below is forgeable.

## Step 2: The global block-list

```sh
kubectl apply -f - <<'YAML'
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
YAML
```

`DENY`, because a block-list subtracts. An `ALLOW` with no narrowing would close
every hostname this shared gateway serves.

`remoteIpBlocks`, not `ipBlocks`: the latter matches the connection peer, which
behind any proxy is the proxy.

## Step 3: The office-only admin path

"Deny `/admin*` unless the client is in the office range" is a single `DENY` rule
with an inverted source condition:

```sh
kubectl apply -f - <<'YAML'
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
YAML
```

Say it out loud, starting with the action: *DENY requests whose client is **not**
in 203.0.113.0/24 **and** whose path is `/admin*`.* Both parts of the rule are
ANDed, which is what keeps the restriction confined to that subtree — without
the `to` block this would deny the whole internet.

`/admin*` rather than `/admin`, so `/admin/users` is covered too.

## Step 4: Prove all five

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
sleep 2
call() { curl -s -o /dev/null -w "$1 $2: %{http_code}\n" \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: $1" "http://localhost:8080$2"; }
call 10.1.2.3    /book
call 192.168.5.5 /book
call 10.1.2.3    /admin
call 203.0.113.9 /admin
call 192.168.5.5 /admin
```

```text
10.1.2.3 /book: 200
192.168.5.5 /book: 403
10.1.2.3 /admin: 403
203.0.113.9 /admin: 404
192.168.5.5 /admin: 403
```

The `404` is the pass: that request was allowed through and the application had
no such handler. Note also the last line — the office rule and the block-list
overlap, and a request caught by either is denied, because both are `DENY` and
either match ends the decision.

Stop the port-forward: `kill %1`.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Everything is `403`.** The admin rule probably has no `to` block, so it
  denies every path for every client outside the office range.
- **`/admin` is reachable from `10.1.2.3`.** The condition is not inverted — you
  wrote `remoteIpBlocks` where `notRemoteIpBlocks` was needed.
- **Nothing is blocked at all.** The policies are in the wrong namespace, or the
  selector does not match the gateway pod.
