# Section 060: Authorization In Ambient Mode

Ambient mode takes the sidecar out of every pod. A shared relay on each node, **ztunnel**, carries the traffic and does the mutual TLS. Anything that must read HTTP runs in a separate **waypoint** pod, and you only get one where you ask for it.

That split changes authorization. The `AuthorizationPolicy` object keeps the same fields, but about half of them only work when a waypoint stands in the signal's path. A policy that nothing enforces looks exactly like one that works, which makes this a favourite exam topic.

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

## The Learning Path

### 1. Authorization In Ambient Mode, L4 And L7
*   **Module Reader:** **[Module 1: Authorization In Ambient Mode, L4 And L7](./module-01/course.md)**
    Parts, in reading order:
    1. [The Ambient Dataplane](./module-01/course-01-the-ambient-dataplane.md)
    2. [What ztunnel Can Enforce](./module-01/course-02-what-ztunnel-can-enforce.md)
    3. [A Rule With Nowhere To Run](./module-01/course-03-a-rule-with-nowhere-to-run.md)
    4. [Deploy A Waypoint](./module-01/course-04-deploy-a-waypoint.md)
    5. [Ask Who Holds The Rule](./module-01/course-05-ask-who-holds-the-rule.md)
    6. [Wrap-Up: Mission Debrief](./module-01/course-06-wrap-up.md)
*   **Hands-on Playground:** `sections/section-060/module-01/playground`: the only playground in this course that runs Istio 1.30.5 in **ambient mode**, installed with Helm (`istio-base`, `istiod`, `istio-cni`, `ztunnel`) plus the Gateway API CRDs. The Starfleet, the `shuttle` client and the `probe` echo service run on the planet `starfleet`, which carries the label `istio.io/dataplane-mode=ambient`. No sidecars, no waypoint, no `AuthorizationPolicy`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/module-01/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Allow Only Known Ships At L4](./module-01/labs/lab-02/README.md)**: read the [task](./module-01/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-02
        astrona submit -c sections/section-060/module-01/labs/lab-02
        ```
    *   **[Enforce L4 And L7 Policy In Ambient Mode](./module-01/labs/lab-01/README.md)** (its own small app, `notification-service` with two clients): read the [task](./module-01/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-01
        astrona submit -c sections/section-060/module-01/labs/lab-01
        ```

**No sidecars here.** Never point `-c istio-proxy` or `istioctl proxy-config` at an app pod in this section. Use `istioctl ztunnel-config` for ztunnel, and point `istioctl proxy-config` at the waypoint.

The playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear it down with `astrona destroy <name>` when you are finished — the name is printed in the module's playground callout.

---

## Capstone

**[Ambient Authorization Capstone](./capstone/labs/lab-01/)** — Split one access requirement across the two ambient enforcement points, and prove which component holds which half.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/capstone/labs/lab-01
astrona submit -c sections/section-060/capstone/labs/lab-01
```
