# Overview: Authorize HTTP Traffic Between Workloads (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits.
There is no task, no `astrona submit` and no pass or fail. Explore, break
things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is mission control: it sends every proxy its orders and
  issues every ship its ID badge (its certificate).
- Mesh-wide **access logs**, so every proxy writes one line per request. This
  is the ship's flight log. A signal the guard turned away shows up in the
  log of the ship that **received** it, for example
  `kubectl logs -n starfleet -l app=probe -c istio-proxy --tail=5`.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge` (the flagship page), `cargo` (supply ship), `scout` v1, v2 and
    v3, and `navcom` (navigation computer). Each one runs under its own
    service account: `starfleet-bridge`, `starfleet-cargo`,
    `starfleet-scout`, `starfleet-navcom`.
  - **`shuttle`**, your client pod, service account `shuttle`.
  - **`fortio`**, a second client with another identity: it has no service
    account of its own, so it runs as `default`.
  - **`probe`** v1 and v2 behind one Service on port `8000` (service account
    `probe`). It echoes what it receives (`/get`, `/headers`, `/post`,
    `/status/...`), so it is the easiest ship to protect and test.
- A **`PeerAuthentication` named `default` in `STRICT` mode** for
  `starfleet`. It is the precondition, not the subject: every caller that gets
  in has done the secret handshake (mTLS), so `principals` and `namespaces`
  rules have a checked name to compare.
- Namespace **`outpost`** with **no** sidecar injection, and the **`drifter`**
  in it. The drifter has no communications officer and no ID badge. Under
  `STRICT`, its plain-text signals into `starfleet` are cut off before any
  `AuthorizationPolicy` runs.
- **No `AuthorizationPolicy`.** Every signal that passes the handshake is
  allowed. Writing the guest lists is the point of the module.
- The bridge page at <http://127.0.0.1:9080/productpage>. Watch it break and
  come back as you add policies.

The ship identities (the names on the ID badges) follow from the service
accounts:

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
# 3 signals from the shuttle (service account shuttle); prints each status code
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- $*"; }
# 1 signal from fortio (service account default); prints the status code
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
# 1 signal from the drifter on the outpost (no sidecar, no identity); prints the status code
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" "$@"; }
```

Use them like this: `from_shuttle http://probe:8000/get`,
`from_shuttle -X POST http://probe:8000/post`,
`from_fortio http://probe:8000/get` (add `-payload hello` to make fortio
send a `POST`), and `from_drifter http://probe.starfleet:8000/get` (the
drifter lives on another planet, so it needs the namespace in the name).

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
  just the status code, and find the matching line in the probe's flight log.
- Add a second policy with `rules: [{}]` next to allow-nothing. Everything is
  open again: one empty rule matches every signal.
- Allow only the shuttle to `GET` the probe. Then try `POST` from the shuttle
  and `GET` from fortio. Both are turned away, for different reasons.
- Swap `principals` for `namespaces: ["starfleet"]` and see fortio get in too.
- Write a rule for `paths: ["/status/200"]` and call `/status/201`. Then try
  `["/status/*"]`.
- Apply the least-privilege guest lists for the whole fleet, then try to reach
  `scout` or `navcom` straight from the shuttle.
- Break a `selector` on purpose (`app: navcomm`) and use
  `istioctl proxy-config listener` and `istioctl analyze` to tell "wrong rule"
  from "never arrived".

For exam-style practice with checked solutions, see
[practice.md](./practice.md).

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
