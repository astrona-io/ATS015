# A Guest List Cannot Overrule The Ban

A banned list on its own is easy to predict. The real test comes when a guest list and a banned list both fit the same signal, astronaut. In this part you write a guest list that explicitly lets the shuttle in, and watch the banned path stay shut anyway.

You also meet the one practical problem this creates: two different `403` replies that look exactly the same to the caller.

## Add a guest list on top of the ban

The commands below need the `probe-deny-status` policy on the probe: a `DENY` for every path under `/status/`, for every caller. Check that it is there with `kubectl get authorizationpolicy -n starfleet`. Now you add an `ALLOW` policy to the same ship.

<!-- astrona:playground:renew -->

### Let the shuttle read anything

This guest list lets exactly one caller, the shuttle, send `GET` signals to the probe. It names no path, so it covers every path, including `/status/200`.

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

No warning this time. An `ALLOW` with only HTTP fields simply never fits a TCP signal, so nothing extra is blocked.

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

Look at the second line. The guest list says "the shuttle may `GET` anything", and `/status/200` is a `GET` from the shuttle. The signal is still refused. The guard found a fitting `DENY` rule first, and the decision ended there. It never read `probe-allow-shuttle-get`.

The last two lines are refused for a different reason. Now that a guest list exists, the probe is in default-deny. A `POST` is not on the list, and fortio is not on the list.

### The rule this shows

**A `DENY` match beats every `ALLOW`.** Not usually, not "unless the `ALLOW` is more specific". The guard walks its steps in order, and the banned list comes first.

This is different from how `PeerAuthentication` works. There, the narrowest rule wins: a rule for one workload overrides a rule for the whole namespace. `AuthorizationPolicy` has no such idea. Know which of the two you are dealing with before you answer an exam question about "which one wins".

So you **cannot** cut an exception out of a `DENY` by adding an `ALLOW`. If one banned path must stay reachable, you have to write the exception into the `DENY` itself, by narrowing its paths or with a negative field such as `notPaths`.

## Two 403s, two different reasons

You now have two `403` replies from the same probe: one from the banned list, one from a missing guest list entry. To the caller, they look the same. This section shows where the difference is written down.

### Same reply for the caller

Print the bodies of both refusals from the caller's side:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s $PROBE/status/200; echo
kubectl exec -n starfleet deploy/fortio -c fortio -- fortio curl -quiet $PROBE/get 2>/dev/null | tail -1; echo
```

```text
RBAC: access denied
RBAC: access denied
```

`fortio curl` prints the reply headers first, so `tail -1` keeps only the body. The `2>/dev/null` hides kubectl's `command terminated with exit code 1`: fortio exits with an error code when the reply is not `200`.

Both say `RBAC: access denied`. The caller cannot tell a `DENY` hit from an `ALLOW` miss.

### Different notes in the guard's log

Now read the probe's flight log for each signal:

```sh
probe_guard_log status/200
probe_guard_log 'GET /get'
```

```text
[2026-10-09T08:07:10.309Z] "GET /status/200 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[starfleet]-policy[probe-deny-status]-rule[0]] - "-" 0 19 0 - "-" "curl/8.11.1" "053c49b6-b1c1-40d1-b863-600c90a87918" "probe:8000" "-" inbound|8080|| - 10.244.0.14:8080 10.244.0.12:52784 outbound_.8000_._.probe.starfleet.svc.cluster.local default
[2026-10-09T08:07:10.368Z] "GET /get HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "fortio.org/fortio-1.69.5" "3dc00c6f-73f4-4a28-a9cb-8372145cb549" "probe:8000" "-" inbound|8080|| - 10.244.0.14:8080 10.244.0.15:33064 outbound_.8000_._.probe.starfleet.svc.cluster.local default
```

The helper prints the newest matching line. Fortio sent the last `GET /get`, so the second line is fortio's signal (its user agent is `fortio.org/fortio-1.69.5`). If you see a `200` from the shuttle there, run the fortio command above again.

The first note names the policy and the rule that fit: a `DENY` did it. The second says `matched_policy[none]`: no policy fit, so the signal fell through to the end of the guest list. When you debug a `403`, read the receiving ship's log first. It tells you whether to look at your banned list or at your guest list.

You can also list every policy on the planet to see what the guard has to work with:

```sh
kubectl get authorizationpolicy -n starfleet
```

```text
NAME                      ACTION   AGE
probe-allow-shuttle-get   ALLOW    66s
probe-deny-status         DENY     2m56s
```

The `ACTION` column shows at a glance which policies are guest lists and which are banned lists.

> [!TIP]
> When a `403` surprises you, run `kubectl get authorizationpolicy -A` first. A `DENY` without a `selector` in another policy, or one in the `istio-system` root namespace (which covers the whole mesh), is easy to forget, and it beats every guest list you are reading.

## Common pitfalls

> [!WARNING]
> - **Trying to reopen a banned path with an `ALLOW`.** The guard never reaches it. Change the `DENY` instead.
> - **Thinking a more specific `ALLOW` wins.** There is no "most specific wins" for `AuthorizationPolicy`. That rule belongs to `PeerAuthentication`.
> - **Assuming the `403` tells you which policy fired.** It does not. Read `rbac_access_denied_matched_policy[...]` in the receiving ship's log.
> - **Forgetting that the new `ALLOW` changed more than one thing.** It also turned on default-deny for the probe, so fortio and every `POST` are now refused.

> *A `DENY` does not outvote an `ALLOW`. It ends the decision before the `ALLOW` is read.*
