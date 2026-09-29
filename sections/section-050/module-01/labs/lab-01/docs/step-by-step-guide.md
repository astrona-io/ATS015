# Step-by-Step Guide: LAB015-050-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Find out what the gateway actually sees

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
sleep 2
curl -s -o /dev/null -w 'before: %{http_code}\n' -H "Host: booking.ica.local" http://localhost:8080/book
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=3
```

The access log is the only place the request and the addresses appear together.
Note that the connection appears to come from inside the cluster — a
`port-forward` tunnels through the API server and the kubelet, so the gateway's
**connection peer** is a node address, not your laptop.

That is the same situation as a load balancer in production, and it is why
`ipBlocks` is the wrong field here: it matches the peer, which is the
intermediary.

## Step 2: Confirm the topology setting

```sh
kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' | grep -A2 gatewayTopology
```

```text
gatewayTopology:
  numTrustedProxies: 1
```

With a count of 1, the gateway counts back one trusted hop in
`X-Forwarded-For` and treats the address it lands on as the client. Anything a
client injected further left is ignored. Without this setting the header would be
attacker-controlled and the rule below would be decoration.

## Step 3: Write the policy

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > authorizationpolicy-gateway-ip-deny.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-deny
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
kubectl apply -f authorizationpolicy-gateway-ip-deny.yaml
```

Three things worth naming:

- **`namespace: istio-system`** — the policy is delivered to the proxies its
  selector matches *within its own namespace*, and the gateway pod does not run
  in `gwauthz-demo`.
- **`selector: istio: ingressgateway`** — the `demo` profile's gateway label.
  Confirm it on a cluster you did not install:
  `kubectl -n istio-system get pods --show-labels | grep gateway`.
- **`action: DENY`** — a block-list subtracts specific ranges. An `ALLOW` with no
  `hosts` or `paths` narrowing would close every hostname this shared gateway
  serves.

## Step 4: Test both clients

```sh
curl -s -o /dev/null -w 'xff 10.1.2.3:    %{http_code}\n' \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: 10.1.2.3" http://localhost:8080/book
curl -s -o /dev/null -w 'xff 192.168.5.5: %{http_code}\n' \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: 192.168.5.5" http://localhost:8080/book
```

```text
xff 10.1.2.3:    200
xff 192.168.5.5: 403
```

Two identical requests differing only in a header. Note that this is a `403`,
with a body — the connection was accepted and the request parsed before anything
refused it. A gateway denial is authorization, not a transport rejection.

Setting `X-Forwarded-For` by hand is fine *here* because the port-forward is
acting as the single trusted hop. In production the trusted hop is a load
balancer you control, which is the whole difference between this being a
demonstration and being a vulnerability.

Stop the port-forward with `kill %1`.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Both requests return `200`.** The policy is in the wrong namespace, or its
  selector matches no pod. Check
  `kubectl -n istio-system get authorizationpolicy`.
- **Both requests return `403`.** The rule is probably an `ALLOW` that closed the
  gateway, or the CIDR is wider than intended.
- **The allowed request is `403` and the denied one `200`.** The condition is
  inverted — check for a `not…` field.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
