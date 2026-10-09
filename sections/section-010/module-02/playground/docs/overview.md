# Overview: Enforce mTLS With PeerAuthentication At Three Scopes (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits.
There is no task, no `astrona submit` and no pass or fail. Explore, break
things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is Istio's control plane: it sends configuration to every
  proxy, and it also signs the certificate of every workload in the mesh.
- Mesh-wide **access logs**, so every proxy writes one line per request. You
  read the access log with
  `kubectl logs -n starfleet deploy/shuttle -c istio-proxy`.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `navcom` and `scout` v1, v2 and v3, all on port `9080`.
  - **`shuttle`**, your client pod inside the mesh. Its requests carry its
    identity, `spiffe://cluster.local/ns/starfleet/sa/shuttle`.
  - **`probe`** v1 and v2 behind one Service. The Service port is `8000`; the
    pods listen on container port `8080`. Its `/headers` answer shows the
    `X-Forwarded-Client-Cert` header when a request arrived over mTLS.
- Namespace **`outpost`**, with **no** sidecar injection. Its one pod, the
  **`drifter`**, has no sidecar proxy (`1/1`), so everything it
  sends is plain text.
- **No `PeerAuthentication` and no `DestinationRule`.** The default mode,
  `PERMISSIVE`, is in force, so both the shuttle and the drifter get answers.

## Helpers

Paste this once in each new terminal. `from_shuttle` sends one request from
inside the mesh. `from_drifter` sends one from outside the mesh and also prints
`curl`'s exit code: `56` means the connection was reset.

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" --max-time 5 "$@"; }
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}" --max-time 5 "$@" 2>/dev/null; echo "  exit=$?"; }
PROBE_URL=http://probe.starfleet:8000/get
SCOUT_URL=http://scout.starfleet:9080/reviews/0
```

Use them like this: `from_shuttle $PROBE_URL`, `from_drifter $SCOUT_URL`.

## Example files

The playground's source folder, `examples/01-mtls/`, holds the YAML the
module's parts use. It is not on your machine when you start the playground
with `astrona run --git`; the parts show every file in full, so save your own
copies from there. The table is a map of what the examples cover:

| File | What it does |
| --- | --- |
| `01-peerauthentication-starfleet-strict.yaml` | `STRICT` for the whole `starfleet` namespace |
| `02-peerauthentication-probe-permissive.yaml` | A `PERMISSIVE` exception for the probe only |
| `03-destinationrule-probe-tls-disable.yaml` | A client-side mistake: callers send plain text to the probe |
| `04-peerauthentication-mesh-wide-strict.yaml` | `STRICT` for the whole mesh |
| `cases/c1-peerauthentication-probe-port-level.yaml` | The probe `STRICT`, but container port `8080` `PERMISSIVE` |
| `cases/c2-peerauthentication-starfleet-permissive.yaml` | A namespace `PERMISSIVE` policy under a mesh-wide `STRICT` one |
| `cases/c3-destinationrule-probe-istio-mutual.yaml` | The client side set to `ISTIO_MUTUAL` on purpose |
| `cases/c4-peerauthentication-probe-disable.yaml` | The probe set to `DISABLE` |

## Things to try

Each idea below is a small change to the files you made while reading the
module. Edit your saved file, apply it with `kubectl apply -f`, and predict the
result before you send a request.

- Before you change anything, call the probe from both clients and look at
  `/headers`. Only the shuttle's request carries `X-Forwarded-Client-Cert`.
- Apply `STRICT` to the `starfleet` namespace. Then put the same YAML in
  `outpost` instead and work out from behaviour alone what it became.
- Add a `selector` to a namespace-wide policy and see how much stops being
  covered.
- Write `portLevelMtls` with `8000` (the Service port) instead of `8080`
  (the container port). Call the probe from the drifter and see that the
  exception does nothing.
- Set `mode: DISABLE` on the probe while the namespace says `STRICT`, then
  call it from the shuttle. Predict first: does the shuttle still get `200`?
- Run `istioctl x describe pod` on a probe pod after each change, and read
  the mode it says is in effect and the policies it lists.
- Time how long a policy takes to take effect, and how long deleting it takes
  to undo. No pod restarts.

For exam-style practice with checked solutions, see
[practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete peerauthentication --all -A
kubectl delete destinationrule --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-010-02`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-010-02`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`. The drifter showing `1/1` is
  correct.

## When you're done

```sh
astrona destroy ats-015-playground-010-02
```

(`astrona destroy` takes the environment name, not the configuration path.)
