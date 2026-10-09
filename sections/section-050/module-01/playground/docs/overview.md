# Overview: Authorize By Source IP At The Ingress Gateway (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio, an ingress gateway and the Starfleet,
and then waits. There is no task, no `astrona submit` and no pass or fail.
Explore, break things, `astrona destroy`, start over.

Here you guard the **ingress gateway**, the spaceport arrival gate: the one
door that signals from outside the solar system come through. You decide who
may pass by the address a signal comes from.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm. `istio-base` and `istiod` live in
  `istio-system`. `istiod` is mission control: it sends every proxy its orders.
- The **ingress gateway** on the planet `istio-ingress`. Its Deployment and
  its Service are both called `istio-ingress`, and its pods carry the label
  **`istio=ingress`**. A policy for the gate must live in `istio-ingress` and
  select that label.
- Mesh-wide **access logs**, so every proxy writes one line per signal. Read
  the gate's flight log with
  `kubectl logs -n istio-ingress deploy/istio-ingress --tail=1`.
- Namespace **`starfleet`** (the planet you work on), labelled for injection, with:
  - **The Starfleet**: `bridge` (the flagship page on `/productpage`, and its
    API on `/api/v1/products`), `cargo`, `navcom` and `scout` v1, v2 and v3.
  - **`probe`** v1 and v2 on port `8000`, an echo service. Its `/headers`
    page shows the headers that reached it.
  - **`shuttle`**, a client pod inside the mesh.
- A **`Gateway` and a `VirtualService`** for `starfleet.example.com` on port
  `80`. `/headers` goes to `probe`, everything else to `bridge`. They are
  ready-made so you can focus on the policies.
- **No `AuthorizationPolicy`**, and **`numTrustedProxies` is not set**: the
  gate does not trust any relay in front of it yet.

You also need `istioctl` 1.30.5 and `helm` on your own machine. `astrona run`
used `helm` to install Istio, so it is there already.

### Reaching the gateway

`kind` has no cloud load balancer, so nothing outside the cluster can reach
the gateway on its own. `astrona run` keeps two port forwards running for you.
A port forward is a tunnel from your machine into the cluster.

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` (answers once a `Gateway` has an HTTPS server) |

Check them with `astrona port-forward list`. You do not need to start a
`kubectl port-forward` yourself.

The tunnel matters for this module. It ends **inside** the gateway pod, so
the gateway sees every signal arrive from `127.0.0.1`, not from your laptop.
Read the flight log before you trust any address range.

## Helpers

Paste this into each new terminal. `gate_status` sends one signal through the
gateway to a path and prints only the status code. A second argument is put
in the `X-Forwarded-For` header, the list of addresses a relay adds:

```sh
gate_status() {
  if [ -n "$2" ]; then
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" \
      -H "X-Forwarded-For: $2" "http://127.0.0.1:8080$1"
  else
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" \
      "http://127.0.0.1:8080$1"
  fi; }
gate_log() { kubectl logs -n istio-ingress deploy/istio-ingress --tail=${1:-1}; }
```

Use them like this: `gate_status /productpage`,
`gate_status /productpage 192.168.5.5`, then `gate_log`.

To see which client address the gateway decided on, ask it for its listener
settings. `xffNumTrustedHops` appears only when `numTrustedProxies` is set:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops
```

## Things to try

- Before you write any policy, send a signal and find the address the gateway
  sees, at the end of the `gate_log` line.
- Put a gateway policy in `starfleet` instead of `istio-ingress`. It is
  accepted and blocks nothing.
- Copy `istio: ingressgateway` from an older example into the selector. No pod
  on this Helm install has that label, so nothing is blocked.
- Write an `ipBlocks` allow-list for `10.0.0.0/8`, then for `127.0.0.1/32`.
  Compare.
- Write a `remoteIpBlocks` deny for `192.168.0.0/16` **before** you set
  `numTrustedProxies`, and send `gate_status /productpage 192.168.5.5`. It
  still passes: without trusted relays, the gateway ignores the header.
- Set `numTrustedProxies: 1`, restart the gateway and try again.
- Send two addresses: `gate_status /productpage "192.168.5.5, 10.1.2.3"`.
  Which one did the gateway use? Then try `numTrustedProxies: 2`.
- Open `/api/v1/products` to one network only, and check that
  `/productpage` stays open for everyone.
- Send a denied signal and look at the `bridge` flight log
  (`kubectl logs -n starfleet deploy/bridge-v1 -c istio-proxy --tail=3`). The
  signal never arrived there.
- Read which headers the gateway sent on to the probe, before and after you
  set `numTrustedProxies`:
  `curl -s -H "Host: starfleet.example.com" -H "X-Forwarded-For: 10.1.2.3" http://127.0.0.1:8080/headers`.

For exam-style practice with solutions, see [practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n istio-ingress
kubectl delete authorizationpolicy --all -n starfleet
```

`numTrustedProxies` stays as you last set it. To remove it, run the
`helm upgrade istiod ...` command again with `numTrustedProxies: 0` in the
values file, then `kubectl rollout restart deployment/istio-ingress -n istio-ingress`.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-050-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-050-01`.
- `gate_status` prints `000` or `404` right after a gateway restart: the port
  forward still points at the old pod for a moment. Check
  `astrona port-forward list` and wait about thirty seconds.

## When you're done

```sh
astrona destroy ats-015-playground-050-01
```

(`astrona destroy` takes the environment name, not the configuration path.)
