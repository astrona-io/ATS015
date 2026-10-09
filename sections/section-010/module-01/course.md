# Inspect Workload Identity And Certificates

Every security rule you write in this course comes down to one string. It looks like this:

```text
spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge
```

That string is a workload's **identity**: the name in its certificate. A `PeerAuthentication` decides whether a workload must present its certificate. An `AuthorizationPolicy` decides what a workload with that identity may do. Before you write either one, you need to know exactly where the name comes from. Most "my rule blocks a request it should allow" problems are a gap between the identity you assumed and the identity the workload really has.

In this module you follow one identity from the moment its certificate is issued to the security rule that matches on it. You read real certificates from real pods. Then you write one small `AuthorizationPolicy` to prove that the identity is what the rule checks.

## Learning objectives

After this module you can:

- Name the Kubernetes object that decides a workload's identity, and explain why two workloads can share one identity.
- Describe how a certificate is issued, from the pod's start to a certificate in its proxy, and name the proof the pod shows.
- Read the SPIFFE name from a live certificate with `istioctl proxy-config secret` and `openssl`.
- Tell a workload's own certificate (`default`) apart from the root certificate (`ROOTCA`) it also holds.
- Turn a SPIFFE name into the exact `principals` value an `AuthorizationPolicy` expects.
- State a certificate's default lifetime, what renews it, and what a stale certificate points to.
- Predict what breaks when `meshConfig.trustDomain` changes, and name the setting that makes the change safe.

## Before you start

This section lists what you should know already and what is in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, pods, and running a command inside a pod with `kubectl exec`.
- **How the mesh works.** A sidecar proxy (Envoy) is a proxy container that Istio adds to each pod; all inbound and outbound traffic of the pod passes through it. `istiod` is Istio's control plane; it sends configuration and certificates to every proxy.

You do not need to have written any Istio security object yet. This module is the layer underneath all of them.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5** already installed with Helm. There is **no** `PeerAuthentication` and **no** `AuthorizationPolicy`. That is on purpose: every workload gets its certificate even when no rule uses it.

The sample workloads run in the namespace **`starfleet`**. Each workload runs under its own service account, a Kubernetes object that names who a pod runs as. The service account decides the workload's identity.

| Workload | Service account | What it is |
| --- | --- | --- |
| `bridge` | `starfleet-bridge` | Web frontend; it calls `cargo` and `scout` |
| `cargo` | `starfleet-cargo` | Backend that returns item details |
| `scout` v1, v2, v3 | `starfleet-scout` | One backend in three versions, sharing one service account |
| `navcom` | `starfleet-navcom` | Backend that `scout` v2 and v3 call for the star rating |
| `shuttle` | `shuttle` | Your test client; you send test requests from here with `curl` |
| `probe` v1, v2 | `probe` | An HTTP echo server that sends back what it receives (port `8000`) |
| `fortio` | `default` | A second client with no service account of its own |

A second namespace, **`outpost`**, has sidecar injection switched off. Its one pod, the **`drifter`**, has no sidecar proxy and so no certificate at all.

You also need `jq` and `openssl` on your own machine. Most Linux and macOS systems have `openssl`; install `jq` with your package manager if `jq --version` fails.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
