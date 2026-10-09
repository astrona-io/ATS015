# Authorize By Source IP At The Ingress Gateway

Inside the mesh, every pod has a workload identity: a name in its certificate that Istio gives it. So a policy can ask "which workload sent this request?". At the edge of the mesh that question has no answer. A request from outside comes from a laptop or a server on the internet. It has no mesh identity, and often no client certificate either.

What you often do have is an **IP address**: an office network, a partner's servers, or a block of addresses that keeps attacking you. Istio can allow or deny requests based on that address with an `AuthorizationPolicy`, the Istio object that allows or denies requests to a workload. You place it on the **ingress gateway**: an Envoy proxy at the edge of the mesh that accepts all traffic from outside the cluster.

There is a catch, and it is the heart of this module. Istio has two different fields for "the address the request came from", and they mean different things. Behind a load balancer only one of them is right, and it is only safe with one more setting.

The exam expects you to secure the edge by hand and prove it works. Address rules are easy to get wrong in a way that looks fine: the policy is accepted, and it blocks nobody, or everybody. This module trains the one habit that prevents that: before you write an address range, find out which address the gateway really sees.

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

You should know the basics of an `AuthorizationPolicy`. A policy has a `selector` (which pods it applies to), an `action` (`ALLOW` or `DENY`) and `rules`. Once any `ALLOW` policy applies to a pod, every request that matches none of its rules is denied. A `DENY` that matches always wins over an `ALLOW`.

You should also know what the ingress gateway is made of. It is an Envoy proxy in its own pod. A `Gateway` object opens a listener on it, that is, a port the proxy accepts connections on. A `VirtualService` then routes the requests that come in. Beyond that, you need Kubernetes basics: namespaces, Deployments, Services, pod labels and `kubectl`.

Your playground is one `kind` cluster with **Istio 1.30.5**, installed with Helm. A `kind` cluster is a Kubernetes cluster that runs in containers on your machine. The ingress gateway runs in the namespace **`istio-ingress`**, and its pod carries the label **`istio=ingress`**.

The sample app runs in the namespace **`starfleet`**. It is the Bookinfo sample from the Istio documentation, with new names. The workload you reach through the gateway is **`bridge`**, the web frontend. Its page is on `/productpage` and its small API on `/api/v1/products`. The **`probe`** HTTP echo server is also behind the gateway on `/headers`, and it shows the headers that reached it.

A **`Gateway` and a `VirtualService`** for the host **`starfleet.example.com`** are already applied, so the gateway answers from the start. **No `AuthorizationPolicy`** exists yet, and **`numTrustedProxies` is not set**.

`astrona run` keeps a port forward open: a tunnel from your machine into the cluster. It goes from `http://127.0.0.1:8080` to the gateway's port `80`, and from `https://127.0.0.1:8443` to port `443`. That tunnel plays a real part in this module. It ends inside the gateway pod, so the gateway sees every request arrive from `127.0.0.1`, never from your laptop. In other words, it behaves like a proxy in front of the gateway.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Every part uses two small shell helpers, so paste them into each new terminal. `gate_status` sends one request through the gateway to a path and prints the status code. A second argument goes into the `X-Forwarded-For` header. `gate_log` prints the last lines of the gateway's access log:

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

The module follows one question from start to finish: which address did this request really come from, and can the gateway believe it?

**Apply An AuthorizationPolicy To The Ingress Gateway** starts with where a gateway policy must live, and why denying at the gateway is worth it. **Match The Connection's Source With `ipBlocks`** shows the first address field, and why a proxy hides the real client from it. **Set `numTrustedProxies` For `X-Forwarded-For`** explains the header that carries the client's address, and the one number that decides which entry to believe.

The last two parts put this to work, each followed by a graded lab. **Block A Client Range With `remoteIpBlocks`** denies an attacking range by its real address. **Allow One Path From One Network Only** opens one path to one network, reads back everything that decides the result, and asks what an address is really worth. A short **Summary** closes the module.
