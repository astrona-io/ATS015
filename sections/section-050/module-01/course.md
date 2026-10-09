# Authorize By Source IP At The Ingress Gateway

So far, every request you checked came from a pod inside the mesh. Those pods have a workload identity: a name in their certificate that Istio gives them. So a policy could ask "which workload sent this?". At the edge of the mesh that question has no answer. A request from outside comes from a laptop or a server on the internet. It has no mesh identity, and often no client certificate either.

What you often do have is an **IP address**: an office network, a partner's servers, or a block of addresses that keeps attacking you. Istio can allow or deny requests based on that address with an `AuthorizationPolicy` (an Istio object that allows or denies requests to a workload). You place it on the **ingress gateway**: an Envoy proxy at the edge of the mesh that accepts all traffic from outside the cluster.

There is a catch, and it is the heart of this module. Istio has two different fields for "the address the request came from". They mean different things. Behind a load balancer only one of them is right, and it is only safe with one more setting.

## Learning objectives

After this module you can:

- Write an `AuthorizationPolicy` that applies to the ingress gateway, in the right namespace and with the right selector.
- Explain where a denied request stops when the gateway denies it, and what that saves the mesh.
- Tell `ipBlocks` (the address of whoever opened the connection) from `remoteIpBlocks` (the original client), and pick the right one for a setup.
- Describe how the `X-Forwarded-For` header grows as a request passes proxies, and which entry the gateway uses.
- Set `numTrustedProxies` with Helm, prove the gateway uses it, and explain what goes wrong when the number is too low or too high.
- Block a client range at the gateway, and open one path to one network only, without closing the rest of the gateway.
- Find the address the gateway really saw, and the policy that denied a request, in the gateway's access log.

## Before you start

This section lists what this module expects you to know, and what is in the playground. Check both before you start the parts.

### What you should already know

- **`AuthorizationPolicy` basics.** A policy has a `selector` (which pods it applies to), an `action` (`ALLOW` or `DENY`) and `rules`. Once any `ALLOW` policy applies to a pod, every request that matches none of its rules is denied. A `DENY` that matches always wins over an `ALLOW`.
- **The ingress gateway.** It is an Envoy proxy in its own pod. A `Gateway` object opens a listener (a port the proxy accepts connections on) on it, and a `VirtualService` routes the requests that come in.
- **Kubernetes basics.** Namespaces, Deployments, Services, pod labels and `kubectl`.

### What is in your playground

Your playground is one `kind` cluster (a Kubernetes cluster that runs in containers on your machine) with **Istio 1.30.5**, installed with Helm.

- The **ingress gateway** runs in the namespace **`istio-ingress`**. Its pod carries the label **`istio=ingress`**.
- The **Starfleet** sample app runs in the namespace **`starfleet`**. It is the Bookinfo sample app that the official Istio docs use, with space names. The workload you reach through the gateway is **`bridge`**, the web frontend: its page is on `/productpage` and its small API on `/api/v1/products`. The **`probe`** HTTP echo server is also behind the gateway on `/headers`, and shows the headers that reached it.
- A **`Gateway` and a `VirtualService`** for the host **`starfleet.example.com`** are already applied, so the gateway answers from the start.
- **No `AuthorizationPolicy`** exists, and **`numTrustedProxies` is not set**.
- `astrona run` keeps a port forward (a tunnel from your machine into the cluster) open from `http://127.0.0.1:8080` to the gateway's port `80`, and from `https://127.0.0.1:8443` to port `443`.

That tunnel plays a real part in this module. It ends inside the gateway pod, so the gateway sees every request arrive from `127.0.0.1`, never from your laptop. It behaves like a proxy in front of the gateway.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Two helpers to paste first

Paste these into each new terminal. `gate_status` sends one request through the gateway to a path and prints the status code. A second argument goes into the `X-Forwarded-For` header. `gate_log` prints the last lines of the gateway's access log:

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

1. **[Apply An AuthorizationPolicy To The Ingress Gateway](./course-01-guard-the-arrival-gate.md)**: where a policy for the gateway must live, and why denying at the gateway is worth it.
2. **[Match The Connection's Source With `ipBlocks`](./course-02-who-opened-the-connection.md)**: the first address field, and why a proxy hides the real client from it.
3. **[Set `numTrustedProxies` For `X-Forwarded-For`](./course-03-trust-the-right-number-of-relays.md)**: the `X-Forwarded-For` header and the `numTrustedProxies` setting.
4. **[Block A Client Range With `remoteIpBlocks`](./course-04-block-a-client-range.md)**: the second address field in use, and your first lab.
5. **[Allow One Path From One Network Only](./course-05-one-path-one-network.md)**: open one path to one network, read back what is in force, and what an address is worth. Your second lab.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, questions to check yourself, and cleaning up.

## Why this matters

The exam expects you to secure the edge by hand, on a live cluster, and to prove it works. Address rules look simple, so they are easy to get wrong in a way that looks fine: the policy is accepted, and it blocks nobody, or everybody. This module trains the one habit that prevents that: before you write an address range, find out which address the gateway really sees.
