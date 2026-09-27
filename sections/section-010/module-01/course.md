# Inspect Workload Identity And Certificates

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-010/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/playground
> astrona destroy ats-015-playground-010-01
> ```

Every security rule in this course eventually comes down to one string, and it looks like this:

```text
cluster.local/ns/identity-demo/sa/booking-sa
```

That is a workload's **mesh identity**. `PeerAuthentication` decides whether it has to be proven. `AuthorizationPolicy` decides what it is allowed to do. Before either of those is worth writing, it is worth knowing exactly where the string comes from, because almost every "my policy denies traffic that should be allowed" problem is a mismatch between the identity you assumed and the identity the workload actually has.

This module does no configuring. It follows one certificate from the request that created it to the policy field that matches on it.

## How this module is organised

1. **[Part 1 — How a workload gets its identity](./course-01-how-identity-is-issued.md)** — the service account as the source, the SPIFFE URI form, and the issuance path from `istio-agent` through istiod's CA to the proxy.
2. **[Part 2 — Reading the certificate a proxy holds](./course-02-reading-the-certificate.md)** — the `istioctl proxy-config` command family, the two secrets every proxy carries, and decoding the SAN.
3. **[Part 3 — From SAN to policy principal](./course-03-principals-rotation-trust-domain.md)** — converting the URI into a `principals` value, certificate lifetime and rotation, the trust domain, and the one-pass method for settling an unexpected denial.

## Learning objectives

After this module you can:

- Name the Kubernetes object that determines a workload's mesh identity, and explain why two pods can share one identity.
- Describe the issuance path from pod start to a certificate in the proxy, and name what proves the workload's claim to the CA.
- Read the SPIFFE URI out of a workload certificate's Subject Alternative Name with `istioctl proxy-config secret` and `openssl`.
- Distinguish a proxy's leaf certificate from the root CA certificate it also holds, and say what each is for.
- Convert a SPIFFE URI into the exact `principals` string an `AuthorizationPolicy` expects.
- State a workload certificate's default lifetime, what renews it, and what a stale certificate actually indicates.
- Predict what breaks when `meshConfig.trustDomain` changes, and name the field that makes a migration survivable.

## Before you start

You should be comfortable with `kubectl` — listing pods, reading a resource with `-o jsonpath`, and running a command inside a pod with `kubectl exec`. You do not need to have written any Istio object yet; this module is the layer underneath them.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile), `istioctl` and `openssl` on your PATH, and one injected namespace:

- **`identity-demo`** — `booking-service-v1` running under the service account `booking-sa`, `notification-service-v1` and a `tester` client pod, both of which were given no service account and therefore run as `default`.

No `PeerAuthentication` and no `AuthorizationPolicy` exist yet. That is deliberate: identity is issued regardless of whether any policy uses it, and seeing that is half the point.

## Where this fits

Istio's security objects are usually taught as a list of YAML fields, which hides the fact that they all read from the same source. The control plane, `istiod`, runs a certificate authority. Every injected pod's `istio-agent` asks that CA for a certificate at startup, proving who it is with its Kubernetes service account token. The CA writes the resulting identity into the certificate, and from then on every mutual TLS handshake in the mesh carries it. `principals`, `namespaces` and `requestPrincipals` in later modules are all just different ways of matching on what that handshake produced.
