# Authorization In Ambient Mode

Ambient mode takes the sidecar out of every pod. A shared proxy on each node, **ztunnel**, carries the traffic and does the mutual TLS. Anything that must read HTTP runs in a separate **waypoint** pod, and you only get one where you ask for it.

That split changes authorization. The `AuthorizationPolicy` object keeps the same fields, but about half of them only work when a waypoint is in the request's path. A policy that nothing enforces looks exactly like one that works, which makes this a favourite exam topic.

One module. Workload identity, policy structure and evaluation order work the same as in sidecar mode; only the place where each rule is enforced changes.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- The division of labour between ztunnel (L4, HBONE, mutual TLS) and a waypoint (L7).
- Which fields ztunnel can enforce alone — `principals`, `namespaces`, `ipBlocks`, destination `ports` — and which cannot work without a waypoint.
- That an L7 rule with no waypoint is accepted and ignored when it uses `targetRefs`, and refuses every caller when it uses a `selector` (ztunnel drops the rule it cannot check).
- `targetRefs` attachment — to a `Service` for that service's waypoint, to a Gateway API `Gateway` for the waypoint itself — and when a label `selector` is still the right form.
- That identity needs no waypoint: ztunnel does mTLS over HBONE, so `principals` works at L4.
- Telling an L4 denial (a connection error, `000` from `curl`) from an L7 denial (`403`).
- `istioctl ztunnel-config workload` and `... policy` as the ambient equivalents of `istioctl proxy-config`.
- Deploying a waypoint with `istioctl waypoint apply`, and why enrolment is a separate step from deployment.

---

<!-- astrona:playground -->