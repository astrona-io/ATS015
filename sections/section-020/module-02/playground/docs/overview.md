# Overview: DENY Policies And Evaluation Order (Playground)

This is a **playground**, not a lab. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is Istio's control plane: it sends every proxy its
  configuration and issues the workload certificates.
- Mesh-wide **access logs**, so every proxy writes one line per request. On
  the pod that **receives** a request, the line also names the policy that
  refused the request.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `scout` v1/v2/v3 and `navcom`, each with its own
    service account (`starfleet-bridge`, `starfleet-cargo` and so on).
  - **`shuttle`**, your client pod. Service account `shuttle`, so its identity
    is `cluster.local/ns/starfleet/sa/shuttle`.
  - **`fortio`**, a second client with another identity. It has no service
    account of its own, so it runs as `default`.
  - **`probe`** v1 and v2 behind one Service on port `8000`. It is an echo
    service: `/get`, `/post`, `/delete`, `/status/<code>`, `/headers` and
    `/anything/<any path>` all answer. Any other path returns `404` from the
    probe itself, which tells you the request got past the
    authorization check.
- A **`PeerAuthentication` named `default` in `starfleet`, mode `STRICT`**.
  Every caller must use mTLS and present its certificate, so policies can
  trust its identity.
- Namespace **`outpost`** without injection, with the **`drifter`**: a client
  with no sidecar and no certificate. Under `STRICT`, the starfleet pods refuse
  its plain-text requests before any `AuthorizationPolicy` is checked.
- **No `AuthorizationPolicy`.** Everything inside `starfleet` is allowed.
- Every pod in `starfleet` shows `2/2` in `kubectl get pods`: the app plus its
  `istio-proxy` sidecar. Istio 1.30 starts the sidecar as a native sidecar (a
  special init container), and it still counts in the `READY` column. The
  drifter shows `1/1`.

## Helpers

Paste these once in each new terminal:

```sh
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- shuttle $*"; }
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
probe_guard_log() { sleep 5; kubectl logs -n starfleet -l app=probe -c istio-proxy --since=60s | grep "$1" | sort | tail -1; }
PROBE=http://probe:8000
```

- `from_shuttle $PROBE/get` sends three requests from the shuttle and prints
  each status code. Extra `curl` options are passed on, for example
  `from_shuttle -X POST $PROBE/post`.
- `from_fortio $PROBE/get` sends one request from fortio and prints its status
  code, for example `Code 200`. `from_fortio -X POST $PROBE/post` sends a
  `POST`.
- `probe_guard_log status/200` shows the newest access log line for that
  path from the probe's sidecar proxy. The proxy writes its log in small batches, so the helper waits
  five seconds before it reads.

Wait up to about a minute after every `kubectl apply` before you trust a
test. New connections get the new policy at once, but a connection that was
already open keeps the old rules for a while. Testing too early gives a mix
like `200 200 403`.

## Things to try

Each idea below is a small change to the files you made while reading the
module. The module's parts show the full YAML for every step.

- Apply only a `DENY` policy to the probe, then call a path it does not name.
  Predict the result first: a workload with only `DENY` policies lets
  everything else in.
- Add an `ALLOW` that explicitly lets the shuttle `GET` every path, and check
  whether the denied path opens. It does not.
- Send one request that a `DENY` refuses and one that no `ALLOW` matches. Both
  give `403`. Tell them apart with `probe_guard_log`.
- Apply an `ALLOW` with `rules: [{}]`, then a `DENY` with `rules: [{}]`. The
  namespace denies everything, and the open `ALLOW` policy changes nothing.
- Write `paths: ["/anything/admin"]` without the `*`, then call
  `/anything/admin/users`.
- Write a `DENY` with `notMethods: ["GET"]` and say the sentence out loud
  before you test it.
- Patch a `DENY` to `action: AUDIT` and watch the denied path open again.
- Delete every policy and confirm that a workload with no policy at all allows
  everything.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-020-02`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-020-02`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-020-02
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

Two exam-style tasks for this playground. Start the playground
first, and paste the helpers from the Helpers section above. The
solutions use them.

Try each task on your own first, then open the solution. Wait up to about a
minute after each apply before you trust a test.

### Task 1: one caller may not read the status pages

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

### Task 2: deny all requests to navcom, then prove no ALLOW policy opens it

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
