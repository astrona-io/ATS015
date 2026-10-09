# Overview: Migrate A Namespace From PERMISSIVE To STRICT mTLS (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is mission control: it sends every proxy its orders.
- Mesh-wide **access logs**, so every proxy writes one line per signal. This is
  the ship's flight log, and you read it with
  `kubectl logs -n starfleet deploy/cargo-v1 -c istio-proxy`.
- Namespace **`starfleet`** (the planet you migrate), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `scout` v1 to v3 and `navcom`. In this module you send
    signals to `cargo` on port `9080`.
  - **`shuttle`**, your client inside the fleet. Its signals leave through its
    communications officer (the `istio-proxy` sidecar), so they use mTLS.
  - **`probe`** v1 and v2, the echo probe. Its Service listens on port
    `8000`, and the container listens on `8080`. The parts do not need it;
    it is there for your own experiments.
- Namespace **`outpost`**, with injection switched **off** on purpose. Its one
  ship, the **`drifter`**, has no communications officer (`1/1`), so it sends
  plain signals. It is the caller that would break if `starfleet` switched to
  `STRICT` today.
- **No `PeerAuthentication`.** `starfleet` runs in the default `PERMISSIVE`
  mode: it accepts both mTLS and plain signals.

## Helpers

Paste this once in each new terminal. `plain_signals` reads cargo's own
counter and shows how many signals arrived with mTLS (`mutual_tls`) and how
many arrived plain (`none`):

```sh
plain_signals() {
  kubectl -n starfleet exec deploy/cargo-v1 -c istio-proxy -- \
    pilot-agent request GET stats/prometheus \
    | grep '^istio_requests_total' | grep 'reporter="destination"' \
    | sed -n 's/.*connection_security_policy="\([^"]*\)".* \([0-9]*\)$/\1 \2/p' \
    | awk '{sum[$1]+=$2} END {for (k in sum) print k, sum[k]}'
}
```

## Things to try

The YAML for each step is in the module's parts, and in
`examples/01-migrate-to-strict/`. Save it to a file and apply it with
`kubectl apply -f`.

- Send signals to `cargo` from the shuttle and from the drifter, then run
  `plain_signals`. Both `mutual_tls` and `none` appear.
- Switch `starfleet` to `STRICT` before you move the drifter. Watch the
  drifter's `curl` fail with exit code 56 (connection reset), then roll back
  with the `PERMISSIVE` file and time how fast it works again.
- Label `outpost` with `istio-injection=enabled` and list the drifter's
  containers *before* you restart it. The label alone changes nothing.
- After the drifter is in the fleet, run `plain_signals` again. The `none`
  count stays, because counters never reset. It just stops going up.
- With `starfleet` on `STRICT`, add a `DestinationRule` for `cargo` with
  `tls.mode: DISABLE`. The shuttle now gets `503` with the flag `UC`, although
  both ships are in the fleet.

For exam-style practice with solutions, see [practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete peerauthentication,destinationrule --all -n starfleet
kubectl label namespace outpost istio-injection-
kubectl -n outpost rollout restart deploy/drifter
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-010-03`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-010-03`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-010-03
```

(`astrona destroy` takes the environment name, not the configuration path.)
