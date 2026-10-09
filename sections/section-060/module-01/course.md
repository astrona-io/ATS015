# Authorization In Ambient Mode, L4 And L7

In **ambient mode**, Istio runs no sidecar proxy in your pods. A sidecar proxy is a proxy container that Istio adds to each pod, so that all of the pod's traffic passes through it. Ambient mode removes it. Instead, a shared proxy on each node, called **ztunnel**, carries every connection and handles mutual TLS (mTLS: both sides show a certificate, so the connection is encrypted and both identities are checked). Anything that must read the inside of a request, such as its HTTP method or path, runs in a separate Envoy proxy pod called a **waypoint**. You only get a waypoint where you create one.

Two short names run through the whole module. **L4** (layer 4, the transport layer) is the connection: who is calling, from which address, to which port. **L7** (layer 7, the application layer) is the request inside the connection: the HTTP method, the path, the headers. ztunnel reads only L4. A waypoint reads L7.

That split changes authorization. The `AuthorizationPolicy` object is the same one you know from sidecar mode, with the same fields. But about half of those fields only work when a waypoint is in the request's path. A policy that nothing enforces looks exactly like one that works: `kubectl` accepts it and lists it. On the exam, a rule on methods or paths written the sidecar way is accepted and then does nothing. This module teaches you to tell the two apart, and to put each rule where a component can enforce it.

The module follows one namespace from no rules to rules at both layers, in five parts. **The Ambient Dataplane** shows what replaces the sidecar: ztunnel, the HBONE tunnel and how a pod joins the mesh with a label. **What ztunnel Can Enforce** writes an identity rule that works with no waypoint and shows the refused connection it gives. **An L7 Rule With No Waypoint** writes an HTTP rule before any waypoint exists, and shows the two opposite ways it fails. **Deploy A Waypoint** adds the waypoint and watches the same policy start to work. **Find Which Component Enforces A Rule** asks each component what it holds, so you can find the cause when a policy does nothing.

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

You need to know how an `AuthorizationPolicy` is built. A policy has a `selector` (which pods), an `action` (`ALLOW` or `DENY`) and `rules` with `from`, `to` and `when`. As soon as one `ALLOW` policy selects a workload, everything it does not allow is refused, and a `DENY` that matches always beats an `ALLOW`.

You also need workload identity. Every workload in the mesh gets a certificate for its Kubernetes service account, the object that names who a pod runs as. A `principals` rule names that identity as `cluster.local/ns/<namespace>/sa/<service-account>`, without the `spiffe://` prefix. Beyond that, you need Kubernetes basics: namespaces, Deployments, Services, labels and `kubectl exec`.

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

Every pod shows `1/1`: only the app, no `istio-proxy`. There is **no waypoint** and **no `AuthorizationPolicy`** yet, because you write them in this module. The web paths built into the images keep their original names. A request to `cargo` goes to `http://cargo:9080/details/0`, and the probe echoes any method at `http://probe:8000/anything`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
