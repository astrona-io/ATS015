# Section 060: Authorization In Ambient Mode

Ambient mode removes the per-pod sidecar. A node-level component, **ztunnel**, carries traffic and does mutual TLS; anything that needs to understand HTTP runs in a separate **waypoint** pod, deployed only where you ask for it.

That split lands directly on authorization. The `AuthorizationPolicy` object is the same one from section 020, with the same fields — and about half of them quietly stop working unless a waypoint is in the path. A policy that is not enforced looks exactly like one that is, which is what makes this the most examinable corner of ambient mode.

One module, taken last because it reuses everything before it: identity from section 010, policy structure from section 020, and claim rules from section 030 all behave the same way here.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- The division of labour between ztunnel (L4, HBONE, mutual TLS) and a waypoint (L7).
- Which fields ztunnel can enforce alone — `principals`, `namespaces`, `ipBlocks`, destination `ports` — and which cannot work without a waypoint.
- That an L7 rule in an ambient namespace with no waypoint is accepted, listed, and silently ignored.
- `targetRefs` attachment — to a `Service` for that service's waypoint, to a Gateway API `Gateway` for the waypoint itself — and when a label `selector` is still the right form.
- That identity needs no waypoint: ztunnel does mTLS over HBONE, so `principals` works at L4.
- Telling an L4 denial (a connection error, `000` from `curl`) from an L7 denial (`403`).
- `istioctl ztunnel-config workload` and `... policy` as the ambient equivalents of `istioctl proxy-config`.
- Deploying a waypoint with `istioctl waypoint apply`, and why enrolment is a separate step from deployment.

---

## The Learning Path

### 1. Authorization In Ambient Mode, L4 And L7
*   **Module Reader:** **[Module 1: Authorization In Ambient Mode, L4 And L7](./module-01/course.md)**
    Deep-dive parts, in reading order:
    1. [The ambient dataplane](./module-01/course-01-the-ambient-dataplane.md)
    2. [What ztunnel can enforce](./module-01/course-02-what-ztunnel-can-enforce.md)
    3. [Waypoints and L7 policy](./module-01/course-03-waypoints-and-l7-policy.md)
    4. [Tooling, and carrying sidecar knowledge across](./module-01/course-04-tooling-and-carrying-across.md)
*   **Hands-on Playground:** `sections/section-060/module-01/playground` — the only playground in this course installed with the **`ambient`** profile. Namespace `ambient-authz` is enrolled (`istio.io/dataplane-mode=ambient`) and holds two clients with deliberately different service accounts. No waypoint, no `AuthorizationPolicy`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/module-01/playground
    ```
*   **Graded lab:** **[Enforce L4 And L7 Policy In Ambient Mode](./module-01/labs/lab-01/)** — read the
    [exam question](./module-01/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-01
    astrona submit -c .
    ```

Note that there are **no sidecars** in this playground. Commands from earlier sections that target `-c istio-proxy` or `istioctl proxy-config` on an application pod have no counterpart here; use `istioctl ztunnel-config` instead.

The playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear it down with `astrona destroy <name>` when you are finished — the name is printed in the module's playground callout.

---

## Capstone

**[Ambient Authorization Capstone](./capstone/labs/lab-01/)** — Split one access requirement across the two ambient enforcement points, and prove which component holds which half.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/capstone/labs/lab-01
astrona submit -c .
```
