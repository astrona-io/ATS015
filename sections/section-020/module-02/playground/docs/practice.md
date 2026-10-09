# Practice: DENY Policies And Evaluation Order

Two exam-style tasks for this playground. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solutions use them.

Try each task on your own first, then open the solution. Wait up to about a
minute after each apply before you trust a test.

## Task 1: one caller may not read the status pages

> In namespace `starfleet`, `fortio` must get `403` for every path under
> `/status/` on `probe`. The `shuttle` must still reach `/status/200`, and
> `fortio` must still reach `/get`. Do not use an `ALLOW` policy.

<details><summary>Solution</summary>

A `DENY` with both a `from` and a `to` part. Inside one rule, both parts must
fit, so only fortio's requests to `/status/...` are refused. Fortio runs as the
service account `default`.

Save this as `authorizationpolicy-probe-deny-fortio-status.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-fortio-status
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
    to:
    - operation:
        paths: ["/status/*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-deny-fortio-status.yaml
```

Then check the result:

```sh
from_fortio $PROBE/status/200
from_fortio $PROBE/get
from_shuttle $PROBE/status/200
```

```text
Code 403
Code 200
200 200 200 <- shuttle http://probe:8000/status/200
```

Fortio is refused on `/status/` only. The shuttle's identity does not fit the
`from` part, so the rule does not fit its requests.

Clean up: `kubectl delete -f authorizationpolicy-probe-deny-fortio-status.yaml`

</details>

## Task 2: deny all requests to navcom, then prove no ALLOW policy opens it

> In namespace `starfleet`, an `ALLOW` policy named `navcom-allow-all` lets
> every request reach `navcom`. Lock `navcom` completely with a second policy,
> so that every request to it gets `403`, while `navcom-allow-all` stays in
> place. Requests to `probe` must not be affected.

<details><summary>Solution</summary>

First create the open `ALLOW` policy from the task.

Save this as `authorizationpolicy-navcom-allow-all.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-allow-all
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
  action: ALLOW
  rules:
  - {}
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-allow-all.yaml
```

Now the lockdown: a `DENY` with one empty rule, on `navcom` only. The empty
rule fits every request, and the sidecar proxy checks `DENY` policies before
`ALLOW` policies.

Save this as `authorizationpolicy-navcom-deny-all.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-deny-all
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
  action: DENY
  rules:
  - {}
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-deny-all.yaml
```

Then check the result:

```sh
from_shuttle http://navcom:9080/ratings/0
from_shuttle $PROBE/get
kubectl get authorizationpolicy -n starfleet
```

```text
403 403 403 <- shuttle http://navcom:9080/ratings/0
200 200 200 <- shuttle http://probe:8000/get
NAME               ACTION   AGE
navcom-allow-all   ALLOW    60s
navcom-deny-all    DENY     60s
```

The `ALLOW` policy is still there, and `navcom` refuses every request anyway. The
probe has no policy, so it still answers.

Clean up: `kubectl delete authorizationpolicy navcom-allow-all navcom-deny-all -n starfleet`

</details>
