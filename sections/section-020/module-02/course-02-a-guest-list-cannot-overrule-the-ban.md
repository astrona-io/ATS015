# An ALLOW Cannot Override A DENY

A `DENY` policy on its own is easy to predict. The real test comes when an `ALLOW` policy and a `DENY` policy both fit the same request, because many people expect the more specific rule to win. It does not, and exam questions are built on exactly that mistake.

This chapter writes an `ALLOW` policy that explicitly lets the shuttle in, and you watch the denied path stay closed anyway. Along the way you meet the one practical problem this creates: two different `403` responses that look exactly the same to the caller.

## Add an ALLOW policy next to the DENY

The commands below need the `probe-deny-status` policy on the probe: a `DENY` for every path under `/status/`, for every caller. Check that it is there with `kubectl get authorizationpolicy -n starfleet`. Next to it, you now add an `ALLOW` policy to the same workload.

<!-- astrona:playground:renew -->

This `ALLOW` policy lets exactly one caller, the shuttle, send `GET` requests to the probe. It names no path, so it covers every path, including `/status/200`.

Save this as `authorizationpolicy-probe-allow-shuttle-get.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-shuttle-get
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/shuttle
    to:
    - operation:
        methods:
        - GET
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-allow-shuttle-get.yaml
```

```text
authorizationpolicy.security.istio.io/probe-allow-shuttle-get created
```

There is no warning this time. An `ALLOW` with only HTTP fields simply never fits a TCP connection, so nothing extra is blocked.

Wait up to about a minute, then check the result. Predict each line first:

```sh
from_shuttle $PROBE/get
from_shuttle $PROBE/status/200
from_shuttle -X POST $PROBE/post
from_fortio $PROBE/get
```

```text
200 200 200 <- shuttle http://probe:8000/get
403 403 403 <- shuttle http://probe:8000/status/200
403 403 403 <- shuttle -X POST http://probe:8000/post
Code 403
```

Look at the second line. The `ALLOW` policy says "the shuttle may `GET` anything", and `/status/200` is a `GET` from the shuttle. The request is still refused. The sidecar proxy found a fitting `DENY` rule first, and the decision ended there, so it never checked `probe-allow-shuttle-get`.

The last two lines are refused for a different reason. Now that an `ALLOW` policy selects the probe, the probe is in default-deny. No `ALLOW` rule matches a `POST`, and no `ALLOW` rule matches fortio.

The rule behind the second line is short: **a `DENY` match beats every `ALLOW`.** Not usually, and not "unless the `ALLOW` is more specific". The sidecar proxy walks its steps in order, and `DENY` comes first.

This is different from how `PeerAuthentication` works. There, the narrowest rule wins: a rule for one workload overrides a rule for the whole namespace. `AuthorizationPolicy` has no such idea, so know which of the two you are dealing with before you answer an exam question about "which one wins".

It also means you **cannot** cut an exception out of a `DENY` by adding an `ALLOW`. If one denied path must stay reachable, you have to write the exception into the `DENY` itself, by narrowing its paths or with a negative field such as `notPaths`.

## Two 403s, two different reasons

The test above left you with two `403` responses from the same probe: one from a `DENY` match, one from a missing `ALLOW` match. When you debug, you need to know which is which, because the fix lives in a different policy. To the caller, though, they look the same. Print the bodies of both refusals from the caller's side:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s $PROBE/status/200; echo
kubectl exec -n starfleet deploy/fortio -c fortio -- fortio curl -quiet $PROBE/get 2>/dev/null | tail -1; echo
```

```text
RBAC: access denied
RBAC: access denied
```

`fortio curl` prints the response headers first, so `tail -1` keeps only the body. The `2>/dev/null` hides kubectl's `command terminated with exit code 1`, because fortio exits with an error code when the response is not `200`. Both bodies say `RBAC: access denied`, so the caller cannot tell a `DENY` hit from an `ALLOW` miss.

The difference is written down on the other side. Read the access log of the probe's sidecar proxy for each request:

```sh
probe_guard_log status/200
probe_guard_log 'GET /get'
```

```text
[2026-10-09T08:07:10.309Z] "GET /status/200 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[starfleet]-policy[probe-deny-status]-rule[0]] - "-" 0 19 0 - "-" "curl/8.11.1" "053c49b6-b1c1-40d1-b863-600c90a87918" "probe:8000" "-" inbound|8080|| - 10.244.0.14:8080 10.244.0.12:52784 outbound_.8000_._.probe.starfleet.svc.cluster.local default
[2026-10-09T08:07:10.368Z] "GET /get HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "fortio.org/fortio-1.69.5" "3dc00c6f-73f4-4a28-a9cb-8372145cb549" "probe:8000" "-" inbound|8080|| - 10.244.0.14:8080 10.244.0.15:33064 outbound_.8000_._.probe.starfleet.svc.cluster.local default
```

The helper prints the newest matching line. Fortio sent the last `GET /get`, so the second line is fortio's request (its user agent is `fortio.org/fortio-1.69.5`). If you see a `200` from the shuttle there, run the fortio command above again.

The first line names the policy and the rule that fit, so a `DENY` did it. The second says `matched_policy[none]`: no policy fit, so no `ALLOW` rule matched the request. When you debug a `403`, read the receiving pod's access log first. It tells you whether to look at your `DENY` policies or at your `ALLOW` policies.

To see what the sidecar proxy has to work with, you can also list every policy in the namespace:

```sh
kubectl get authorizationpolicy -n starfleet
```

```text
NAME                      ACTION   AGE
probe-allow-shuttle-get   ALLOW    66s
probe-deny-status         DENY     2m56s
```

The `ACTION` column shows at a glance which policies allow and which deny.

> [!TIP]
> When a `403` surprises you, run `kubectl get authorizationpolicy -A` first. A `DENY` without a `selector` in another policy, or one in the `istio-system` root namespace (which covers the whole mesh), is easy to forget, and it beats every `ALLOW` policy you are reading.

A `DENY` does not outvote an `ALLOW`; it ends the decision before the `ALLOW` is checked. So an exception to a `DENY` must live inside the `DENY`, and the receiving pod's access log tells a `DENY` hit from an `ALLOW` miss. What is still open is how far a single rule can reach: what happens when a rule has no conditions at all.

## Common pitfalls

> [!WARNING]
> - **Trying to reopen a denied path with an `ALLOW`.** The sidecar proxy never reaches it. Change the `DENY` instead.
> - **Thinking a more specific `ALLOW` wins.** There is no "most specific wins" for `AuthorizationPolicy`. That rule belongs to `PeerAuthentication`.
> - **Assuming the `403` tells you which policy fired.** It does not. Read `rbac_access_denied_matched_policy[...]` in the receiving pod's access log.
> - **Forgetting that the new `ALLOW` changed more than one thing.** It also turned on default-deny for the probe, so fortio and every `POST` are now refused.
