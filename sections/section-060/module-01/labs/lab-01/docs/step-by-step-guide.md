# Step-by-Step Guide: LAB015-060-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Confirm the starting point

```sh
istioctl ztunnel-config workload --namespace ambient-authz
kubectl -n ambient-authz get gateway
```

```text
NAMESPACE      POD NAME                    ADDRESS      NODE            WAYPOINT  PROTOCOL
ambient-authz  notification-service-v1-…   10.244.0.12  kind-control-…  None      HBONE
ambient-authz  other-client-…              10.244.0.13  kind-control-…  None      HBONE
ambient-authz  tester-…                    10.244.0.14  kind-control-…  None      HBONE

No resources found in ambient-authz namespace.
```

`PROTOCOL: HBONE` means ztunnel is carrying this traffic and doing mTLS for it —
that is what "enrolled" means. `WAYPOINT: None` is the condition the rest of this
depends on.

## Step 2: The L4 rule

Identity is available on the HBONE connection, so ztunnel can enforce this alone:

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > authorizationpolicy-notification-l4.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-l4
  namespace: ambient-authz
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/ambient-authz/sa/tester-sa
YAML
kubectl apply -f authorizationpolicy-notification-l4.yaml

sleep 3
kubectl -n ambient-authz exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester:       %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
kubectl -n ambient-authz exec deploy/other-client -- \
  curl -s -o /dev/null -w 'other-client: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
```

```text
tester:       200
other-client: 000
```

Enforced with no waypoint. And note the `000`: ztunnel has no HTTP layer, so it
refuses the **connection** rather than returning a status.

## Step 3: The L7 rule — and watch it do nothing

```sh
cat > authorizationpolicy-notification-l7.yaml <<'YAML'
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
YAML
kubectl apply -f authorizationpolicy-notification-l7.yaml

sleep 3
kubectl -n ambient-authz exec deploy/tester -- \
  curl -s -o /dev/null -w 'GET (should be blocked): %{http_code}\n' -X GET http://notification-service/notify
```

```text
GET (should be blocked): 200
```

Accepted, listed by `kubectl get`, and completely ignored — nothing in the path
can see that this was a `GET`. The policy is not wrong; it is unenforced.

`targetRefs` rather than a `selector` is deliberate: L7 enforcement happens at
the waypoint in front of a service, not at a pod.

## Step 4: Deploy and enrol a waypoint

```sh
istioctl waypoint apply -n ambient-authz --enroll-namespace
kubectl -n ambient-authz rollout status deployment waypoint
kubectl -n ambient-authz get gateway
```

```text
NAME       CLASS            ADDRESS      PROGRAMMED
waypoint   istio-waypoint   10.96.x.x    True
```

Two things happened, and they are separate: `waypoint apply` created the waypoint
(a Gateway API `Gateway` plus its Deployment), and `--enroll-namespace` set the
label that sends traffic through it. A waypoint without enrolment runs happily
and receives nothing.

## Step 5: The waypoint is now the client, and the L4 rule refuses it

```sh
kubectl -n ambient-authz exec deploy/tester -- \
  curl -s -o /dev/null -w 'POST: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
```

```text
POST: 503
```

Nothing is broken about the waypoint; `notification-l4` is doing exactly what it
says. Enrolment put the waypoint in the path, so the connection that now arrives
at the pod comes from the **waypoint's** identity —
`cluster.local/ns/ambient-authz/sa/waypoint` — and a rule that admits only
`tester-sa` refuses it. The service stops answering everyone, including the
client the rule was written for.

This is the thing to take away: a workload-scoped L4 identity rule and a
waypoint cannot both be in play. Once a service has a waypoint, the original
client identity is visible **at the waypoint**, not at the pod.

## Step 6: One policy, at the waypoint

Remove the L4 rule and let the `targetRefs` policy do both halves:

```sh
kubectl -n ambient-authz delete authorizationpolicy notification-l4
sleep 5
kubectl -n ambient-authz exec deploy/tester -- sh -c \
  'curl -s -o /dev/null -w "tester POST: %{http_code}\n" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w "tester GET:  %{http_code}\n" -X GET  http://notification-service/notify'
kubectl -n ambient-authz exec deploy/other-client -- \
  curl -s -o /dev/null -w 'other-client POST: %{http_code}\n' -X POST http://notification-service/notify
```

```text
tester POST: 200
tester GET:  403
other-client POST: 403
```

All three from one policy: `principals` gives the identity half, `methods` the
verb half, and the waypoint enforces both because it can read the request.

Note that `other-client` now gets `403` rather than the `000` it got in step 2.
The refusal moved from the transport to HTTP when the waypoint took over — same
decision, different layer, and a different thing to look for when debugging.

Ask each component what it holds:

```sh
istioctl ztunnel-config policy --namespace ambient-authz
istioctl proxy-config listener deploy/waypoint -n ambient-authz -o json | grep -i rbac | head
```

With the L4 rule gone, ztunnel lists nothing for this service and the policy
lives on the waypoint.

## Step 7: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`GET` still returns `200`.** Either there is no waypoint, or it exists but
  the namespace/service was never enrolled, or the L7 policy uses a `selector`
  instead of `targetRefs`.
- **`other-client` gets `403` instead of `000`.** Its traffic is going through
  the waypoint and being refused at L7 — which works, but the L4 rule is what the
  task asks for.
- **`tester` gets `000`.** The principal string is wrong; check the service
  account name.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/) — the SPIFFE identity format and where it comes from
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [Ambient mode](https://istio.io/latest/docs/ambient/usage/l4-policy/) — what changes for policy without a sidecar
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
