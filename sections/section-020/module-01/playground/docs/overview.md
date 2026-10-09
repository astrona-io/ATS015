# Overview: Authorize HTTP Traffic Between Workloads (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Istio and the Starfleet, and then waits.
There is no task, no `astrona submit` and no pass or fail. Explore, break
things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is the control plane: it sends every proxy its configuration
  and issues every workload its certificate.
- Mesh-wide **access logs**, so every proxy writes one line per request. A
  request that an `AuthorizationPolicy` denied shows up in the log of the
  workload that **received** it, for example
  `kubectl logs -n starfleet -l app=probe -c istio-proxy --tail=5`.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge` (web frontend), `cargo` (item details backend), `scout` v1, v2
    and v3, and `navcom` (rating backend). Each one runs under its own
    service account: `starfleet-bridge`, `starfleet-cargo`,
    `starfleet-scout`, `starfleet-navcom`.
  - **`shuttle`**, your client pod, service account `shuttle`.
  - **`fortio`**, a second client with another identity: it has no service
    account of its own, so it runs as `default`.
  - **`probe`** v1 and v2 behind one Service on port `8000` (service account
    `probe`). It echoes what it receives (`/get`, `/headers`, `/post`,
    `/status/...`), so it is the easiest workload to protect and test.
- A **`PeerAuthentication` named `default` in `STRICT` mode** for
  `starfleet`. It is the precondition, not the subject: every caller that gets
  in has used mTLS, so `principals` and `namespaces` rules have a verified
  identity to compare.
- Namespace **`outpost`** with **no** sidecar injection, and the **`drifter`**
  in it. The drifter has no sidecar and no certificate. Under
  `STRICT`, its plain-text requests into `starfleet` are cut off before any
  `AuthorizationPolicy` runs.
- **No `AuthorizationPolicy`.** Every request that passes mTLS is
  allowed. Writing the policies is the point of the module.
- The `bridge` page at <http://127.0.0.1:9080/productpage>. Watch it break and
  come back as you add policies.

The workload identities (the SPIFFE IDs in the certificates) follow from
the service accounts:

| Caller | Identity in a `principals` rule |
| --- | --- |
| `shuttle` | `cluster.local/ns/starfleet/sa/shuttle` |
| `fortio` | `cluster.local/ns/starfleet/sa/default` |
| `bridge` | `cluster.local/ns/starfleet/sa/starfleet-bridge` |
| `scout` (all three versions) | `cluster.local/ns/starfleet/sa/starfleet-scout` |
| `drifter` | none: it has no certificate |

## Helpers

Paste these once in each new terminal. Each comment says what the helper
does. Any `curl` options you give `from_shuttle` or `from_drifter` are passed
on.

```sh
# 3 requests from the shuttle (service account shuttle); prints each status code
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- $*"; }
# 1 request from fortio (service account default); prints the status code
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
# 1 request from the drifter in the outpost namespace (no sidecar, no identity); prints the status code
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" "$@"; }
```

Use them like this: `from_shuttle http://probe:8000/get`,
`from_shuttle -X POST http://probe:8000/post`,
`from_fortio http://probe:8000/get` (add `-payload hello` to make fortio
send a `POST`), and `from_drifter http://probe.starfleet:8000/get` (the
drifter runs in another namespace, so it needs the namespace in the name).

Wait a little after every `kubectl apply` before you test. New connections
get the new rules at once, but a connection that was already open can keep
the old rules for up to about a minute. A mix like `200 200 403` means you
tested too early.

## Things to try

Each idea below is a small change to the files you made while reading the
module. Edit your saved file, apply it with `kubectl apply -f`, and watch what
happens. The module's parts show the full YAML for every step.

- Call the probe from the shuttle, from fortio and from the drifter before you
  write any policy, so you know what "open" looks like. The drifter is cut
  off already: that is `STRICT` mTLS, not authorization.
- Apply the allow-nothing policy (`spec: {}`). Read the response body, not
  just the status code, and find the matching line in the probe's access log.
- Add a second policy with `rules: [{}]` next to allow-nothing. Everything is
  open again: one empty rule matches every request.
- Allow only the shuttle to `GET` the probe. Then try `POST` from the shuttle
  and `GET` from fortio. Both are denied, for different reasons.
- Swap `principals` for `namespaces: ["starfleet"]` and see fortio get in too.
- Write a rule for `paths: ["/status/200"]` and call `/status/201`. Then try
  `["/status/*"]`.
- Apply the least-privilege policies for every Starfleet workload, then try to reach
  `scout` or `navcom` straight from the shuttle.
- Break a `selector` on purpose (`app: navcomm`) and use
  `istioctl proxy-config listener` and `istioctl analyze` to tell "wrong rule"
  from "never arrived".

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

This keeps the `STRICT` `PeerAuthentication`, which the module needs.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-020-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-020-01`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar, so
  `STRICT` mTLS cuts it off. Run `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-020-01
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

Two exam-style tasks for this playground. Start the playground
first, and paste the helpers from the Helpers section above. The
solutions use them.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

Start each task from a clean namespace: `kubectl delete authorizationpolicy --all -n starfleet`.
Leave the `STRICT` `PeerAuthentication` in place.

### Task 1: one caller, one method, one path

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

### Task 2: a whole namespace, one path

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
