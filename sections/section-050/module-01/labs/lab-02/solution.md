# Solution Walkthrough

"Only the office may reach the API" turns into one `DENY` rule: deny the API when the client is **not** the office. A `DENY` leaves every request it does not name alone, so the page stays open.

---

## Step 1: Look at the gateway

Open the port forward, find the gateway's label, and send two requests:

```sh
kubectl -n istio-ingress port-forward svc/istio-ingress 8080:80 >/dev/null 2>&1 &
sleep 2
kubectl get pods -n istio-ingress -L istio
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" http://127.0.0.1:8080/productpage
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" http://127.0.0.1:8080/api/v1/products
```

```text
NAME                             READY   STATUS    RESTARTS   AGE   ISTIO
istio-ingress-5f768fb4b6-zxc4q   1/1     Running   0          74s   ingress
200
200
```

The gateway pod lives in `istio-ingress` with the label `istio=ingress`. Both paths are open to everyone.

## Step 2: Confirm the gateway trusts one proxy

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops
```

```text
                            "xffNumTrustedHops": 1,
```

With `1`, the gateway takes the **last** entry of `X-Forwarded-For` as the client address. That is the address `remoteIpBlocks` and `notRemoteIpBlocks` read.

## Step 3: Write the policy

Save this as `authorizationpolicy-api-office-only.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: api-office-only
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - to:
    - operation:
        hosts: ["starfleet.example.com"]
        paths: ["/api/v1/products*"]
    from:
    - source:
        notRemoteIpBlocks: ["203.0.113.0/24"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-api-office-only.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/api-office-only created
```

The warning is normal here. A `DENY` rule with only HTTP fields (a host, a path) cannot be checked on a plain TCP port, so Istio would deny everything on such a port. This gateway only serves HTTP on port `80`, so nothing extra is blocked.

`to` and `from` sit in the **same** rule, so both must match: the request goes to the API, **and** its client is outside the office range. `/api/v1/products*` also covers every path below it, such as `/api/v1/products/0`.

## Step 4: Prove it works

Wait about a minute, so the gateway gets its new configuration. Then paste this helper, and send one request for each corner of the rule:

```sh
gate_status() { curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" \
  -H "X-Forwarded-For: $2" "http://127.0.0.1:8080$1"; }
gate_status /api/v1/products 203.0.113.7
gate_status /api/v1/products 10.1.2.3
gate_status /api/v1/products/0 10.1.2.3
gate_status /productpage 10.1.2.3
gate_status /api/v1/products "203.0.113.7, 10.1.2.3"
```

```text
200
403
403
200
403
```

The office reaches the API, everyone else is denied there, and the page stays open. The last request puts a forged office address in front: the gateway only believes the last entry, `10.1.2.3`, so it is denied.

The gateway's access log shows the denial and the client address together:

```sh
kubectl logs -n istio-ingress deploy/istio-ingress --tail=5 | grep 403
```

```text
[2026-10-09T11:28:18.623Z] "GET /api/v1/products HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-ingress]-policy[api-office-only]-rule[0]] - "-" 0 19 0 - "10.1.2.3,10.244.0.6" "curl/8.7.1" "46a4520d-8200-47f4-bfe2-bd5d95827a32" "starfleet.example.com" "-" outbound|9080||bridge.starfleet.svc.cluster.local - 127.0.0.1:80 10.1.2.3:0 - -
[2026-10-09T11:28:18.635Z] "GET /api/v1/products/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-ingress]-policy[api-office-only]-rule[0]] - "-" 0 19 0 - "10.1.2.3,10.244.0.6" "curl/8.7.1" "cf937fa1-aa77-4818-aaae-e68d863c2684" "starfleet.example.com" "-" outbound|9080||bridge.starfleet.svc.cluster.local - 127.0.0.1:80 10.1.2.3:0 - -
[2026-10-09T11:28:19.096Z] "GET /api/v1/products HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-ingress]-policy[api-office-only]-rule[0]] - "-" 0 19 0 - "203.0.113.7, 10.1.2.3,10.244.0.6" "curl/8.7.1" "baa97cb0-7e61-4d79-b9e8-b6bbdddc9c11" "starfleet.example.com" "-" outbound|9080||bridge.starfleet.svc.cluster.local - 127.0.0.1:80 10.1.2.3:0 - -
```

Each line names the policy and ends with the client address the gateway decided on, `10.1.2.3:0`. The last line is the forged one: the header held `203.0.113.7, 10.1.2.3`, and the gateway used only the last entry. Envoy writes the access log in small batches, so if a line is missing, wait a few seconds and run the command again.

Stop the port forward with `kill %1`, then submit:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-02
```

---

## Common Mistakes

- **An `ALLOW` with the path and the office range.** The office reaches the API, but every other path is denied too: once an `ALLOW` policy selects the gateway, a request that matches none of its rules is denied.
- **`to` and `from` in two separate rules.** Each rule is its own reason to deny. The API would be closed for everyone, and everyone outside the office would lose the page too.
- **`notIpBlocks` instead of `notRemoteIpBlocks`.** `ipBlocks` fields read the connection peer (`127.0.0.1` behind the port forward), so the office is denied as well.
- **The policy in `starfleet`.** A selector only looks at pods in the policy's own namespace. The gateway pod runs in `istio-ingress`.
- **Testing too fast.** `kubectl apply` returns before the gateway has the new configuration. If the API still answers `200`, wait up to a minute and try again.
