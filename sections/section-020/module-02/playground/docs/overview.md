# Overview: DENY Policies And Evaluation Order (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is mission control: it sends every proxy its orders and
  hands out the ID badges (certificates).
- Mesh-wide **access logs**, so every proxy writes one line per request. This
  is the ship's flight log. On the ship that **receives** a signal, it also
  names the policy that turned the signal away.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `scout` v1/v2/v3 and `navcom`, each with its own
    service account (`starfleet-bridge`, `starfleet-cargo` and so on).
  - **`shuttle`**, your client pod. Service account `shuttle`, so its ID badge
    reads `cluster.local/ns/starfleet/sa/shuttle`.
  - **`fortio`**, a second client with another identity. It has no service
    account of its own, so it runs as `default`.
  - **`probe`** v1 and v2 behind one Service on port `8000`. It is an echo
    service: `/get`, `/post`, `/delete`, `/status/<code>`, `/headers` and
    `/anything/<any path>` all answer. Any other path returns `404` from the
    probe itself, which tells you the signal got past the guard.
- A **`PeerAuthentication` named `default` in `starfleet`, mode `STRICT`**.
  Every caller must show its ID badge, so policies can trust it.
- Namespace **`outpost`** without injection, with the **`drifter`**: a client
  with no sidecar and no ID badge. Under `STRICT`, the starfleet ships refuse
  its plain-text signals before any `AuthorizationPolicy` is read.
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

- `from_shuttle $PROBE/get` sends three signals from the shuttle and prints
  each status code. Extra `curl` options are passed on, for example
  `from_shuttle -X POST $PROBE/post`.
- `from_fortio $PROBE/get` sends one signal from fortio and prints its status
  code, for example `Code 200`. `from_fortio -X POST $PROBE/post` sends a
  `POST`.
- `probe_guard_log status/200` shows the probe's newest flight log line for
  that path. The proxy writes its log in small batches, so the helper waits
  five seconds before it reads.

Wait up to about a minute after every `kubectl apply` before you trust a
test. New connections get the new policy at once, but a connection that was
already open keeps the old rules for a while. Testing too early gives a mix
like `200 200 403`.

## Things to try

Each idea below is a small change to the files you made while reading the
module. The module's parts show the full YAML for every step.

- Apply only a `DENY` policy to the probe, then call a path it does not name.
  Predict the result first: a ship with only a banned list lets everything
  else in.
- Add an `ALLOW` that explicitly lets the shuttle `GET` every path, and check
  whether the banned path opens. It does not.
- Send one signal that a `DENY` refuses and one that no `ALLOW` matches. Both
  give `403`. Tell them apart with `probe_guard_log`.
- Apply an `ALLOW` with `rules: [{}]`, then a `DENY` with `rules: [{}]`. The
  planet locks completely, and the open guest list changes nothing.
- Write `paths: ["/anything/admin"]` without the `*`, then call
  `/anything/admin/users`.
- Write a `DENY` with `notMethods: ["GET"]` and say the sentence out loud
  before you test it.
- Patch a `DENY` to `action: AUDIT` and watch the banned path open again.
- Delete every policy and confirm that a ship with no policy at all allows
  everything.

For exam-style practice, see [practice.md](./practice.md).

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
