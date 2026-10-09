# Inspect Workload Identity And Certificates

Astronaut, every security rule you write in this course comes down to one string. It looks like this:

```text
spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge
```

That string is a ship's **identity**: the name on its ID badge. A `PeerAuthentication` decides whether a ship must show its badge. An `AuthorizationPolicy` decides what a ship with that badge may do. Before either one is worth writing, you need to know exactly where the name comes from. Most "my rule blocks a signal it should let through" problems are a gap between the badge you assumed and the badge the ship really carries.

In this module you follow one badge from the moment it is printed to the security rule that matches on it. You read real certificates from real ships, and you write one small guest list to prove that the badge is what the rule checks.

## Learning objectives

After this module you can:

- Name the Kubernetes object that decides a ship's identity, and explain why two ships can share one identity.
- Describe how a badge is issued, from the ship's start to a certificate in its proxy, and name the proof the ship shows.
- Read the SPIFFE name from a live certificate with `istioctl proxy-config secret` and `openssl`.
- Tell a ship's own certificate (`default`) apart from the root certificate (`ROOTCA`) it also holds.
- Turn a SPIFFE name into the exact `principals` value an `AuthorizationPolicy` expects.
- State a badge's default lifetime, what renews it, and what a stale certificate points to.
- Predict what breaks when `meshConfig.trustDomain` changes, and name the setting that makes the change safe.

## Before you start

Every mission starts with a pre-flight check. This one is short: what you should know, and what waits in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, pods, and running a command inside a pod with `kubectl exec`.
- **How the mesh works.** A sidecar proxy, the communications officer, sits beside every app and handles every signal in or out. `istiod`, mission control, sends each proxy its orders.

You do not need to have written any Istio security object yet. This module is the layer underneath all of them.

### What is in your playground

Your playground is a training solar system: one `kind` cluster with **Istio 1.30.5** already installed with Helm. There is **no** `PeerAuthentication` and **no** `AuthorizationPolicy`. That is on purpose: every ship gets its badge even when no rule uses it.

The ships operate on the planet (namespace) **`starfleet`**. Together, they form the Starfleet fleet, where every ship runs under a dedicated service account. Think of it as the ship’s registration papers: they establish its identity and determine which badge it carries.

| Ship | Service account | Its role |
| --- | --- | --- |
| `bridge` | `starfleet-bridge` | The flagship page; it signals the other ships |
| `cargo` | `starfleet-cargo` | The supply ship |
| `scout` v1, v2, v3 | `starfleet-scout` | Three ship classes of one scout, sharing one set of papers |
| `navcom` | `starfleet-navcom` | The navigation computer the scouts ask for ratings |
| `shuttle` | `shuttle` | Your test client; you send test signals from here with `curl` |
| `probe` v1, v2 | `probe` | An echo probe that sends back what it receives (port `8000`) |
| `fortio` | `default` | A second caller with no papers of its own |

A second planet, **`outpost`**, has sidecar injection switched off. Its one ship, the **`drifter`**, has no communications officer and so no badge at all.

You also need `jq` and `openssl` on your own machine. Most Linux and macOS systems have `openssl`; install `jq` with your package manager if `jq --version` fails.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->