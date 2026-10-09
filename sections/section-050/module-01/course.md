# Authorize By Source IP At The Ingress Gateway

Astronaut, until now every signal you checked came from a ship inside the fleet. Those ships carry an identity that the mesh gave them, so a policy could ask "who are you?". At the edge of the solar system that question has no answer. A signal from outside comes from a laptop or a server on the internet. It has no mesh identity, and often no certificate either.

What you often do have is an **address**: an office network, a partner's servers, or a block of addresses that keeps attacking you. Istio can decide on that address with an `AuthorizationPolicy` (the guard's orders) placed on the **ingress gateway**, the spaceport arrival gate where every signal from outside comes in.

There is a catch, and it is the heart of this module. Istio has two different fields for "the address the signal came from". They mean different things. Behind a load balancer only one of them is right, and it is only safe with one more setting.

## Learning objectives

After this module you can:

- Write an `AuthorizationPolicy` that guards the ingress gateway, in the right namespace and with the right selector.
- Explain where a refused signal stops when the gate refuses it, and what that saves the fleet.
- Tell `ipBlocks` (the address of whoever opened the connection) from `remoteIpBlocks` (the original client), and pick the right one for a setup.
- Describe how the `X-Forwarded-For` header grows as a signal passes relays, and which entry the gateway uses.
- Set `numTrustedProxies` with Helm, prove the gateway uses it, and explain what goes wrong when the number is too low or too high.
- Block a client range at the gate, and open one path to one network only, without closing the rest of the gate.
- Find the address the gateway really saw, and the policy that refused a signal, in the gateway's access log.

## Before you start

Every mission starts with a pre-flight check, astronaut. Here is what this module expects you to know, and what waits for you in the playground.

### What you should already know

- **`AuthorizationPolicy` basics.** A policy has a `selector` (which pods it guards), an `action` (`ALLOW` or `DENY`) and `rules`. Once any `ALLOW` policy guards a pod, every signal that matches none of its rules is refused. A `DENY` that matches always wins over an `ALLOW`.
- **The ingress gateway.** It is an Envoy proxy in its own pod. A `Gateway` object opens a listener on it, and a `VirtualService` routes the signals that come in.
- **Kubernetes basics.** Namespaces, Deployments, Services, pod labels and `kubectl`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5**, installed with Helm.

- The **ingress gateway** runs on the planet (namespace) **`istio-ingress`**. Its pod carries the label **`istio=ingress`**.
- The **Starfleet** lives on the planet **`starfleet`**. It is the Bookinfo sample app that the official Istio docs use, with space names. The ship you reach through the gate is **`bridge`**, the flagship: its page is on `/productpage` and its small API on `/api/v1/products`. The echo **`probe`** is also behind the gate on `/headers`, and shows the headers that reached it.
- A **`Gateway` and a `VirtualService`** for the host **`starfleet.example.com`** are already applied, so the gate answers from the start.
- **No `AuthorizationPolicy`** exists, and **`numTrustedProxies` is not set**.
- `astrona run` keeps a port forward (a tunnel from your machine into the cluster) open from `http://127.0.0.1:8080` to the gateway's port `80`, and from `https://127.0.0.1:8443` to port `443`.

That tunnel plays a real part in this module. It ends inside the gateway pod, so the gateway sees every signal arrive from `127.0.0.1`, never from your laptop. It behaves like a relay in front of the gate.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Two helpers to paste first

Paste these into each new terminal. `gate_status` sends one signal through the gate to a path and prints the status code. A second argument goes into the `X-Forwarded-For` header. `gate_log` prints the last lines of the gate's flight log (the access log):

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

Use them like this: `gate_status /productpage`, `gate_status /productpage 192.168.5.5`, then `gate_log`.

## The parts of this module

1. **[Guard The Arrival Gate](./course-01-guard-the-arrival-gate.md)**: where a policy for the gateway must live, and why refusing at the gate is worth it.
2. **[Who Opened The Connection: `ipBlocks`](./course-02-who-opened-the-connection.md)**: the first address field, and why a relay hides the real client from it.
3. **[Trust The Right Number Of Relays](./course-03-trust-the-right-number-of-relays.md)**: the `X-Forwarded-For` header and the `numTrustedProxies` setting.
4. **[Block A Client Range With `remoteIpBlocks`](./course-04-block-a-client-range.md)**: the second address field in use, and your first mission.
5. **[One Path, One Network](./course-05-one-path-one-network.md)**: open one path to one network, read back what is in force, and what an address is worth. Your second mission.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, questions to check yourself, and cleaning up.

## Why this matters

The exam expects you to guard the edge by hand, on a live cluster, and to prove it works. Address rules look simple, so they are easy to get wrong in a way that looks fine: the policy is accepted, and it blocks nobody, or everybody. This module trains the one habit that prevents that: before you write an address range, find out which address the gate really sees.
