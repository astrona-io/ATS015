# CUSTOM With ALLOW And DENY

A `CUSTOM` policy is one of three actions that can select the same workload. Real setups mix them: an external authorizer checks a path, a `DENY` policy blocks a known bad caller, and an `ALLOW` policy limits the workload to a set of identities. This chapter tests how the three combine, and what the proxy does when the authorizer cannot answer.

<!-- astrona:playground:renew -->

## The order of evaluation

For one request, the sidecar proxy checks the policies of the workload in this order:

1. `CUSTOM` policies. If the authorizer denies, the request is rejected. The check ends there.
2. `DENY` policies. If one matches, the request is rejected.
3. `ALLOW` policies. If no `ALLOW` policy exists, the request is allowed. If one exists, the request must match a rule of at least one `ALLOW` policy or it is rejected.

Two consequences follow. An allow from the authorizer is not final: a `DENY` or a missing `ALLOW` match can still reject the request. And a `CUSTOM` policy never grants access by itself, because `CUSTOM` has no way to override a later rejection.

## A DENY still applies after an allow

Start from the state of the previous chapter: the `CUSTOM` policy `probe-ext-authz` sends `/headers` to the HTTP provider. Add a `DENY` policy that rejects the `fortio` caller. The `fortio` pod runs as the service account `default`, so its identity is `cluster.local/ns/starfleet/sa/default`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-default-sa
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/default"]
```

Apply it. Then send the same request, with the allowing header, from both clients. Define a helper for the second client first:

```sh
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
```

```sh
kubectl apply -f authorizationpolicy-probe-deny-default-sa.yaml
from_shuttle -H "x-ext-authz: allow" $PROBE/headers
from_fortio -H "x-ext-authz: allow" $PROBE/headers
```

The `fortio` image has no `curl`, so the helper uses `fortio load` and prints a line such as `Code 403`. After about a minute, the shuttle gets `200` and the fortio gets `Code 403`. The authorizer allowed both requests. The `DENY` policy rejected the second one afterwards. The authorizer log should list the `fortio` request too, because the check runs before the `DENY` policies.

## An ALLOW policy limits the allowed set

Add an `ALLOW` policy that names only the shuttle on the probe:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-shuttle
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/shuttle"]
```

Now the shuttle passes both gates for `/headers` when it sends `x-ext-authz: allow`, and it passes the `ALLOW` policy for `/ip` as well. A request from any other identity fails the `ALLOW` policy, whatever the authorizer says. The authorizer and the `ALLOW` policy each remove access. Neither adds it.

## When the authorizer cannot answer

The provider field `failOpen` controls what the proxy does when the check fails because the authorizer is unreachable or times out. Its default is `false`: the proxy treats the failure as a denial. The field `statusOnError` sets the status code of that denial, and its default is `403`.

You can watch the default. Stop the authorizer and send the allowed request:

```sh
kubectl scale deploy/ext-authz -n starfleet --replicas=0
from_shuttle -H "x-ext-authz: allow" $PROBE/headers
from_shuttle $PROBE/ip
```

The first request gets `403`, although it carries the allowing header, because no authorizer was there to say so. The second request gets `200`: `/ip` is not sent to the authorizer. Bring the authorizer back:

```sh
kubectl scale deploy/ext-authz -n starfleet --replicas=1
```

With `failOpen: true`, the first request would pass when the authorizer is down. That trades safety for availability, so use it only when the protected path can be open during an outage. The `timeout` field bounds the wait: a check that takes longer than the timeout counts as a failure.

## Common pitfalls

> [!WARNING]
> - **Treating an authorizer allow as final.** A `DENY` policy, or an `ALLOW` policy that does not match, still rejects the request.
> - **Making the authorizer a single point of failure for every path.** A broad `CUSTOM` rule sends all traffic through the authorizer. When it is down and `failOpen` is `false`, every matched request fails.
> - **Leaving `failOpen: true` unreviewed.** It silently opens the path during an outage.
> - **Using a wrong identity in the `DENY`.** A workload without its own service account runs as `default`, so a rule for `default` also matches every other workload in that namespace that has no account of its own.
