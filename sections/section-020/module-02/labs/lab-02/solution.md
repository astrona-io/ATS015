# Solution Walkthrough

The probe's `ALLOW` policy lets every workload in the namespace send anything, and you may not touch it. But the sidecar proxy checks `DENY` policies first. One `DENY` that fits every method except `GET` makes the probe read-only, whatever the `ALLOW` policy says.

---

## Step 1: Look at the starting state

List the policies in the namespace, and send one read and one write from the shuttle:

```sh
kubectl get authorizationpolicy -n starfleet
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "GET:  %{http_code}\n" http://probe:8000/get
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "POST: %{http_code}\n" -X POST http://probe:8000/post
```

```text
NAME                ACTION   AGE
probe-allow-fleet   ALLOW    18s
GET:  200
POST: 200
```

Only the `ALLOW` policy exists, and it lets both requests in.

## Step 2: Write the DENY policy

`notMethods: ["GET"]` fits every request whose method is **not** `GET`. Inside a `DENY`, that means "refuse everything except reads". The rule has no `from` part, so it covers every caller.

Save this as `authorizationpolicy-probe-read-only.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-read-only
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - to:
    - operation:
        notMethods: ["GET"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-read-only.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/probe-read-only created
```

The warning is normal for a `DENY` that uses only HTTP fields such as methods: the sidecar proxy cannot check those on a plain TCP port, so it blocks such ports on the probe completely. The probe only speaks HTTP, so nothing breaks.

A list such as `methods: ["POST", "PUT", "DELETE"]` would leave `PATCH` and every other method you did not name open. The negative field covers them all.

## Step 3: Prove it works

Wait up to about a minute. Old connections keep the old rules until the proxy drains them. Then send reads and writes from both callers:

```sh
for method in GET POST DELETE; do
  endpoint=$(echo $method | tr 'A-Z' 'a-z')
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle $method: %{http_code}\n" -X $method http://probe:8000/$endpoint
done
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle PATCH: %{http_code}\n" -X PATCH http://probe:8000/anything
kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 http://probe:8000/get 2>&1 | grep -o "Code [0-9]*"
kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 -X POST http://probe:8000/post 2>&1 | grep -o "Code [0-9]*"
```

```text
shuttle GET: 200
shuttle POST: 403
shuttle DELETE: 403
shuttle PATCH: 403
Code 200
Code 403
```

The last two lines come from fortio: its read gets `200` and its `POST` gets `403`.

Reads pass for both callers, and every other method is refused, even though `probe-allow-fleet` lets every workload in `starfleet` send anything. The sidecar proxy found a fitting `DENY` rule first, and the decision ended there.

To see which policy refused a write, read the access log of the probe's sidecar proxy:

```sh
sleep 5; kubectl logs -n starfleet -l app=probe -c istio-proxy --since=60s | grep 'POST /post' | sort | tail -1
```

```text
[2026-10-09T08:33:04.948Z] "POST /post HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[starfleet]-policy[probe-read-only]-rule[0]] - "-" 0 19 0 - "-" "fortio.org/fortio-1.69.5" "8fed64e3-3ec9-4502-ac8d-01cad9e6aaed" "probe:8000" "-" inbound|8080|| - 10.244.0.6:8080 10.244.0.9:48470 outbound_.8000_._.probe.starfleet.svc.cluster.local default
```

The `sleep 5` is there because the proxy writes its access log in small batches. The line names `probe-read-only`, rule `0`: the `DENY` policy refused the request, not a missing `ALLOW` match.

Now submit:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-02
```

---

## Common Mistakes

- **Editing or deleting `probe-allow-fleet`.** It works, but it breaks the task. The grader checks that the `ALLOW` policy is unchanged.
- **Writing `methods` instead of `notMethods`.** `DENY` + `methods: ["GET"]` bans reads and lets every write through, the exact opposite.
- **Listing the banned methods one by one.** `PATCH` and other methods you forget stay open. The grader sends a `PATCH`.
- **Adding a `from` part.** A `DENY` for the shuttle only leaves fortio free to write. The `DENY` must cover every caller.
- **Leaving out the `selector`.** Without it, the `DENY` covers every workload in the namespace, not only the probe. The grader checks that it selects `app: probe`.
- **Testing too fast.** If you see a mix like `200 403`, wait up to about a minute and try again.
