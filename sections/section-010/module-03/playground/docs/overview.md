# Overview: Migrate A Namespace From PERMISSIVE To STRICT mTLS (Playground)

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

Exam-style practice tasks with solutions are at the end of this page.

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

## Practice tasks

Two exam-style tasks for this playground, astronaut. Start the playground
first, and paste the `plain_signals` helper from
the Helpers section above.

Try each task on your own first, then open the solution.

### Task 1: move the planet to STRICT without breaking anyone

> Namespace `starfleet` must accept **only mTLS**. The `drifter` in namespace
> `outpost` must still reach `http://cargo.starfleet:9080/details/0` with
> `200` afterwards. Do not move the drifter to another namespace.

<details><summary>Solution</summary>

Work in the safe order: write down `PERMISSIVE`, bring the caller into the
fleet, and only then switch to `STRICT`.

Save this as `peerauthentication-starfleet-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: PERMISSIVE
```

Apply it:

```bash
kubectl apply -f peerauthentication-starfleet-permissive.yaml
```

Bring the drifter into the fleet. The label only works for ships that launch
after it, so restart the drifter:

```bash
kubectl label namespace outpost istio-injection=enabled
kubectl -n outpost rollout restart deploy/drifter
kubectl -n outpost rollout status deploy/drifter
kubectl -n outpost get pods
```

```text
namespace/outpost labeled
deployment.apps/drifter restarted
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
deployment "drifter" successfully rolled out
NAME                       READY   STATUS    RESTARTS   AGE
drifter-67f55b45b7-2vmh9   2/2     Running   0          2s
```

Save this as `peerauthentication-starfleet-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
```

Apply it:

```bash
kubectl apply -f peerauthentication-starfleet-strict.yaml
```

Wait about a minute, so the new orders reach every open connection. Then
check the result:

```bash
kubectl -n outpost exec deploy/drifter -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://cargo.starfleet:9080/details/0
```

```text
200
```

</details>

### Task 2: take the sidecar off again, safely

> Start from the end of task 1: `starfleet` is `STRICT`, and the `drifter` in
> `outpost` has a sidecar. The drifter's owners want the sidecar off their
> ship again. Remove it, and keep the drifter able to reach
> `http://cargo.starfleet:9080/details/0` with `200` the whole time. You may
> move `starfleet` back to `PERMISSIVE`.

<details><summary>Solution</summary>

Undo in the reverse order of the migration: first `PERMISSIVE`, then remove
the sidecar. The other way round, the drifter sends plain signals to a
`STRICT` planet and gets a connection reset.

Apply the `PERMISSIVE` file from task 1 again:

```bash
kubectl apply -f peerauthentication-starfleet-permissive.yaml
```

Wait about a minute, so the new orders reach every proxy. Then switch
injection off for `outpost` and relaunch the drifter without a sidecar:

```bash
kubectl label namespace outpost istio-injection-
kubectl -n outpost rollout restart deploy/drifter
kubectl -n outpost rollout status deploy/drifter
kubectl -n outpost get pods
```

```text
namespace/outpost unlabeled
deployment.apps/drifter restarted
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "drifter" rollout to finish: 1 old replicas are pending termination...
deployment "drifter" successfully rolled out
NAME                       READY   STATUS    RESTARTS   AGE
drifter-5589564f74-qmkd5   1/1     Running   0          0s
```

Then check the result:

```bash
kubectl -n outpost exec deploy/drifter -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://cargo.starfleet:9080/details/0
```

```text
200
```

</details>
