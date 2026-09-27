# Authorization In Ambient Mode, L4 And L7

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-060/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/module-01/playground
> astrona destroy ats-015-playground-060-01
> ```

Ambient mode removes the per-pod sidecar. Instead, a node-level component called **ztunnel** carries traffic between workloads, and anything that needs to understand HTTP runs in a separate pod called a **waypoint** — deployed only where you ask for it.

That split lands directly on authorization. The `AuthorizationPolicy` object is the same one from [section 020](../../section-020/README.md), with the same fields, and about half of those fields quietly stop working. Which half depends on whether a waypoint is in the path, and a policy that is not enforced looks exactly like one that is.

## How this module is organised

1. **[Part 1 — The ambient dataplane](./course-01-the-ambient-dataplane.md)** — ztunnel, HBONE, how traffic is redirected without a sidecar, and what enrolment actually changes.
2. **[Part 2 — What ztunnel can enforce](./course-02-what-ztunnel-can-enforce.md)** — the L4 field set, why identity still works, and the failure signature of an L4 denial.
3. **[Part 3 — Waypoints and L7 policy](./course-03-waypoints-and-l7-policy.md)** — the rule that is accepted and ignored, `targetRefs` attachment, and deploying a waypoint to turn it on.
4. **[Part 4 — Tooling, and carrying sidecar knowledge across](./course-04-tooling-and-carrying-across.md)** — `istioctl ztunnel-config`, the pitfalls, and which of the previous five sections still applies unchanged.

## Learning objectives

After this module you can:

- Describe the ambient dataplane: what ztunnel is, what HBONE carries, and how a pod's traffic is redirected without a sidecar.
- Explain what labelling a namespace `istio.io/dataplane-mode=ambient` changes, and why no pod restart is needed.
- Say which `AuthorizationPolicy` fields ztunnel can enforce on its own, and which cannot work without a waypoint.
- Predict what happens to an L7 rule in an ambient namespace with no waypoint.
- Attach a policy with `targetRefs` and explain how that differs from a label `selector`.
- Deploy a waypoint, enrol traffic through it, and show the same policy taking effect.
- Recognise an L4 denial by its failure signature and tell it apart from an L7 one.
- Use `istioctl ztunnel-config` to find out which component holds which policy.

## Before you start

You need `AuthorizationPolicy` from [section 020](../../section-020/README.md) — `selector`, `action`, `rules`, and how `ALLOW` creates default-deny — and workload identity from [section 010](../../section-010/README.md), because identity works the same way in ambient mode as it does with sidecars.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 installed using the `ambient` profile**, the Gateway API CRDs installed, `istioctl` on your PATH, and:

- **`ambient-authz`** — labelled `istio.io/dataplane-mode=ambient`, so its pods are enrolled. `notification-service-v1` serving port `8084` behind a Service on port 80, plus two client pods with deliberately different identities: `tester` (service account **`tester-sa`**) and `other-client` (service account **`other-sa`**).

No waypoint and no `AuthorizationPolicy` exist yet. Enrolment is done for you because it is a precondition; the policies and the waypoint are the module.

There are **no sidecars** in this playground. Commands from earlier sections that target `-c istio-proxy`, or run `istioctl proxy-config` against an application pod, have no counterpart here.

## Where this fits

This is the last module of the course because it reuses all of it. Identity is still a SPIFFE URI derived from a service account, `principals` still takes it without the `spiffe://` prefix, `ALLOW` still creates default-deny for what it selects, and `DENY` still beats `ALLOW`. What changes is **where enforcement can happen**, and therefore which of the rules you already know how to write will actually do anything.
