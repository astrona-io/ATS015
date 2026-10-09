# Overview: Originate TLS For External Services (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the shuttle, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is mission control: it sends every proxy its orders.
- The mesh at its **`ALLOW_ANY`** default, so ships may signal any outside
  planet. This module is about **who seals** the signal, not about whether it
  may leave.
- Mesh-wide **access logs**, so every proxy writes one line per signal. This
  is the ship's flight log, and you read it with
  `kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1`.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio-injection=enabled`, with **`shuttle`**, your client pod inside the
  mesh. You send every test signal from it with the `curl` command. It shows
  `2/2`: the app plus its `istio-proxy` sidecar, the communications officer.
- **No `ServiceEntry`, `DestinationRule` or `VirtualService`.** Writing them
  is the module.

### Outbound internet

This playground calls `httpbin.org` on ports `80` and `443`. **Without
outbound internet access you see network failures, not mesh behaviour.** Run a
plain `curl https://httpbin.org/get` on your own machine first.

## Helpers

Paste these once in each new terminal. The first prints the status code and
the time of one signal from the shuttle. The second prints the last line of
the shuttle's flight log.

```sh
status_and_time() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 10 "$@"; }
last_log_line() { sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1; }
```

Use them like this: `status_and_time http://httpbin.org/get`, then
`last_log_line`.

## Things to try

The module's parts show the full YAML for every step. The same files are in
`examples/01-egress-tls-origination/` in this folder, if you cloned the
repository.

- Ask httpbin.org how it was reached before anything else:
  `kubectl exec -n starfleet deploy/shuttle -- curl -s http://httpbin.org/get | grep '"url"'`.
  It says `http://`.
- Apply only the `ServiceEntry` with `targetPort: 443`. The server answers
  `400`: plain HTTP arrived on its TLS port.
- Add the `DestinationRule` with `tls.mode: SIMPLE` on port `80`. The same
  call now reports `"url": "https://httpbin.org/get"`.
- Put a wrong name in `subjectAltNames` and read the `503`,
  `URX,UF` and `CERTIFICATE_VERIFY_FAILED` in the flight log.
- Remove `targetPort` from the `ServiceEntry` and read
  `WRONG_VERSION_NUMBER`.
- Add a `VirtualService` with `timeout: 2s` and call
  `http://httpbin.org/delay/4`.
- Compare `istioctl proxy-config cluster deploy/shuttle -n starfleet --fqdn httpbin.org --port 80 -o json`
  before and after the `DestinationRule`. Look for
  `envoy.transport_sockets.tls`.

For an exam-style task with a checked solution, see
[practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete virtualservice,destinationrule,serviceentry --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-040-04`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-040-04`.
- The shuttle shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-040-04
```

(`astrona destroy` takes the environment name, not the configuration path.)
