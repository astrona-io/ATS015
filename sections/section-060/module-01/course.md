# Authorization In Ambient Mode, L4 And L7

In **ambient mode**, Istio runs no sidecar proxy in your pods. A sidecar proxy is a proxy container that Istio adds to each pod, so that all of the pod's traffic passes through it. Ambient mode removes it. Instead, a shared proxy on each node, called **ztunnel**, carries every connection and handles mutual TLS (mTLS: both sides show a certificate, so the connection is encrypted and both identities are checked). Anything that must read the inside of a request, such as its HTTP method or path, runs in a separate Envoy proxy pod called a **waypoint**. You only get a waypoint where you create one.

Two short names run through the whole module. **L4** (layer 4, the transport layer) is the connection: who is calling, from which address, to which port. **L7** (layer 7, the application layer) is the request inside the connection: the HTTP method, the path, the headers. ztunnel reads only L4. A waypoint reads L7.

That split changes authorization. The `AuthorizationPolicy` object is the same one you know from sidecar mode, with the same fields. But about half of those fields only work when a waypoint is in the request's path. A policy that nothing enforces looks exactly like one that works: `kubectl` accepts it and lists it. This module teaches you to tell the two apart, and to put each rule where a component can enforce it.

## Learning objectives

After this module you can:

- Describe the ambient dataplane: what ztunnel does, what the HBONE tunnel carries, and how a pod's traffic reaches ztunnel without a sidecar.
- Explain what the label `istio.io/dataplane-mode=ambient` changes, and why running pods need no restart.
- Say which `AuthorizationPolicy` fields ztunnel can enforce on its own, and which need a waypoint.
- Write an identity rule that ztunnel enforces with no waypoint, and recognise its failure signature: a refused connection, not a `403`.
- Predict what happens to an L7 rule with no waypoint: ignored when it uses `targetRefs`, and blocking everything when it uses a `selector`.
- Deploy a waypoint, send a service's traffic through it, and watch the same policy start to work.
- Use `istioctl ztunnel-config` and the waypoint's own logs to find out which component holds which rule.

## Before you start

This module builds on a few basics. Check that you know them, and look at what is waiting in your playground.

### What you should already know

- **`AuthorizationPolicy` basics.** A policy has a `selector` (which pods), an `action` (`ALLOW` or `DENY`) and `rules` with `from`, `to` and `when`. As soon as one `ALLOW` policy selects a workload, everything it does not allow is refused. A `DENY` that matches always beats an `ALLOW`.
- **Workload identity.** Every workload in the mesh gets a certificate for its Kubernetes service account. A `principals` rule names that identity as `cluster.local/ns/<namespace>/sa/<service-account>`, without the `spiffe://` prefix.
- **Kubernetes basics.** Namespaces, Deployments, Services, labels and `kubectl exec`.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5 in ambient mode**. Helm installed four parts: `istio-base`, `istiod` with the ambient profile, `istio-cni` and `ztunnel`. The Gateway API CRDs are installed too, because a waypoint is a Gateway API `Gateway`.

All the example workloads run in one namespace, **`starfleet`**. It carries the label `istio.io/dataplane-mode=ambient`, so every pod in it is already in the mesh, with **no sidecar**. Each workload runs as its own service account, and that service account is its identity:

| Workload | Service account (its identity) | What it does |
| --- | --- | --- |
| `bridge` | `starfleet-bridge` | The **web frontend**. It calls `cargo` and `scout` to build its page |
| `cargo` | `starfleet-cargo` | A **backend** that returns details about an item |
| `scout` v1, v2, v3 | `starfleet-scout` | One backend in **three versions**. v2 and v3 call `navcom` for star ratings |
| `navcom` | `starfleet-navcom` | The **backend** that returns the star rating |
| `shuttle` | `shuttle` | The **test client**. You send every test request from here, with `curl` |
| `probe` v1, v2 | `probe` | An **HTTP echo server** on port `8000`. It accepts any method, so method rules are easy to test |

Every pod shows `1/1`: only the app, no `istio-proxy`. There is **no waypoint** and **no `AuthorizationPolicy`** yet. You write them in this module.

The web paths built into the images keep their original names. A request to `cargo` goes to `http://cargo:9080/details/0`, and the probe echoes any method at `http://probe:8000/anything`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order. Each one ends with something you have seen work in the playground.

1. **[The Ambient Dataplane](./course-01-the-ambient-dataplane.md)**: ztunnel, the HBONE tunnel, how a pod's traffic is redirected without a sidecar, and how to see that a pod is enrolled.
2. **[What ztunnel Can Enforce](./course-02-what-ztunnel-can-enforce.md)**: the fields ztunnel can check on its own, an identity rule with no waypoint, and the refused connection an L4 denial gives you. Ends with a graded lab.
3. **[An L7 Rule With No Waypoint](./course-03-a-rule-with-nowhere-to-run.md)**: what happens to an HTTP rule when no waypoint exists, and why `targetRefs` and `selector` fail in opposite ways.
4. **[Deploy A Waypoint](./course-04-deploy-a-waypoint.md)**: create a waypoint, send a service's traffic through it, and watch the same policy start to work. Ends with a graded lab.
5. **[Find Which Component Enforces A Rule](./course-05-ask-who-holds-the-rule.md)**: `istioctl ztunnel-config`, the waypoint's logs, a short check for "my policy does nothing", and what stays the same as in sidecar mode.
6. **[Wrap-Up](./course-06-wrap-up.md)**: a recap, the graded labs, questions to check yourself, and cleaning up.

## Why this matters

The exam can give you an ambient namespace and ask for a rule on methods or paths. If you write it the sidecar way, `kubectl` accepts it and nothing happens. Knowing which layer a rule needs, and which component enforces it, is what turns an accepted policy into a working one.
