# Practice: Authorize HTTP Traffic Between Workloads

Two exam-style tasks for this playground. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solutions use them.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

Start each task from a clean namespace: `kubectl delete authorizationpolicy --all -n starfleet`.
Leave the `STRICT` `PeerAuthentication` in place.

## Task 1: one caller, one method, one path

> In namespace `starfleet`, deny everything by default. Then allow **only**
> the fortio workload (service account `default`) to **POST** to `/post` on
> the probe.

<details><summary>Solution</summary>

Two policies: the allow-nothing policy for the whole namespace, and one
narrow `ALLOW` policy for the probe.

Save this as `authorizationpolicy-allow-nothing.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: starfleet
spec: {}
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-allow-nothing.yaml
```

Save this as `authorizationpolicy-probe-allow-fortio-post.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-fortio-post
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/default"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/post"]
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-probe-allow-fortio-post.yaml
```

Then check the result (wait up to about a minute first):

```bash
from_fortio -payload hello http://probe:8000/post
from_fortio http://probe:8000/get
from_shuttle -X POST http://probe:8000/post
```

```text
Code 200
Code 403
403 403 403 <- -X POST http://probe:8000/post
```

fortio sends a `POST` when you give it `-payload`. The shuttle is denied
because it has another identity (`sa/shuttle`), even though it asks for
the same method and path.

</details>

## Task 2: a whole namespace, one path

> In namespace `starfleet`, deny everything by default. Then allow **every**
> workload in the `starfleet` namespace to **GET** `/headers` on the probe.
> Nothing from outside the namespace, and no other path.

<details><summary>Solution</summary>

This needs the `allow-nothing` policy from task 1. Apply it first if you
started from a clean namespace.

Save this as `authorizationpolicy-probe-allow-starfleet-headers.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-starfleet-headers
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["starfleet"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/headers"]
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-probe-allow-starfleet-headers.yaml
```

Then check the result (wait up to about a minute first):

```bash
from_shuttle http://probe:8000/headers
from_fortio http://probe:8000/headers
from_shuttle http://probe:8000/get
```

```text
200 200 200 <- http://probe:8000/headers
Code 200
403 403 403 <- http://probe:8000/get
```

`namespaces` matches the namespace in the caller's certificate, so both the
shuttle and fortio get in. `/get` is a different path, so no rule matches and
the probe's proxy denies it.

</details>
