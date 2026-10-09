# Overview: Inspect Workload Identity And Certificates (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod`, no
  gateways). `istiod` is mission control: it sends every proxy its orders and
  runs the badge office (the certificate authority) that signs every ship's
  certificate.
- Mesh-wide **access logs**: every proxy writes one line per signal. Read them
  with `kubectl logs -n starfleet deploy/probe-v1 -c istio-proxy`.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio-injection=enabled`. Every ship shows `2/2`: the app plus its
  `istio-proxy` sidecar, the communications officer. Each ship runs under a
  service account, and that service account is printed on its badge:

  | Ship | Service account | Identity |
  | --- | --- | --- |
  | `bridge` | `starfleet-bridge` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge` |
  | `cargo` | `starfleet-cargo` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-cargo` |
  | `scout` v1, v2, v3 | `starfleet-scout` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-scout` |
  | `navcom` | `starfleet-navcom` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-navcom` |
  | `shuttle` (your `curl` client) | `shuttle` | `spiffe://cluster.local/ns/starfleet/sa/shuttle` |
  | `probe` v1, v2 (echo, port `8000`) | `probe` | `spiffe://cluster.local/ns/starfleet/sa/probe` |
  | `fortio` (a second caller) | `default` | `spiffe://cluster.local/ns/starfleet/sa/default` |

- Namespace **`outpost`**, with sidecar injection **off**. Its ship, the
  **`drifter`**, shows `1/1`: no communications officer, so no certificate and
  no identity. It can only send plain text.
- **No `PeerAuthentication` and no `AuthorizationPolicy`.** Badges are issued
  anyway: identity does not wait for a rule to use it.
- On your own machine you need `jq` and `openssl` to decode certificates.

## Helpers

Paste these once in each new terminal. `show_badge` prints the SAN (the name
on the badge) of the ship you name; the second argument is the namespace and
defaults to `starfleet`. `check_callers` sends one signal to the probe from
the shuttle, fortio and the drifter, and prints each status code.

```sh
show_badge() {
  istioctl proxy-config secret "$1" -n "${2:-starfleet}" -o json \
    | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
    | base64 --decode | openssl x509 -noout -ext subjectAltName
}
check_callers() {
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" http://probe:8000/get
  kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 http://probe:8000/get 2>&1 | grep -o 'Code [0-9]*' | sed 's/Code /fortio:  /'
  kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" http://probe.starfleet:8000/get
}
```

Use them like this: `show_badge deploy/bridge-v1`, `check_callers`.

## Things to try

Each idea below builds on the files you made while reading the module. The
module's parts show the full YAML and the real output for each step.

- Predict the badge of every ship from the table above, then check three of
  them with `show_badge`. Pick two ships that share a badge.
- Give `fortio` its own service account: create a ServiceAccount called
  `fortio` in `starfleet`, run
  `kubectl set serviceaccount deploy/fortio fortio -n starfleet`, and read its
  badge again. Then think about every rule that had `sa/default` written in it.
- Scale `scout-v1` to three copies and read the badge of two of them. The pod
  names differ; the badge does not.
- With the probe's guest list in place (only the shuttle), edit the principal
  to end in `sa/default` and run `check_callers`. The shuttle and fortio swap
  places.
- Add `spiffe://` in front of the principal. Everyone gets `403`, and
  `istioctl analyze -n starfleet` stays clean.
- Compare the `default` and `ROOTCA` rows of
  `istioctl proxy-config secret deploy/shuttle -n starfleet`, then restart the
  shuttle and compare again. Only the `default` row changes.

For exam-style practice with checked solutions, see
[practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-010-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-010-01`.
- A ship in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar, so no
  badge. Run `kubectl rollout restart deploy -n starfleet`.
- `show_badge` prints `Could not find certificate`: the ship has no proxy, or
  you forgot the namespace (`show_badge deploy/drifter outpost` has nothing to
  show, by design).

## When you're done

```sh
astrona destroy ats-015-playground-010-01
```

(`astrona destroy` takes the environment name, not the configuration path.)
