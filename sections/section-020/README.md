# Section 020: Authorization Policy Fundamentals

Mutual TLS proves a caller is *someone* in the mesh. It has no opinion about whether that someone should be calling this service, on this path, with this method. `AuthorizationPolicy` is where that question is answered, and it is the object the exam tests hardest.

Two modules. Module 1 builds permissions up from nothing: the allow-nothing baseline, the `from` / `to` / `when` structure of a rule, and identity-based rules that depend on the mTLS you turned on in section 010. Module 2 is the other direction — `DENY`, the fixed evaluation order it sits in, and why an `ALLOW` can never rescue traffic a `DENY` matched.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- Why `spec: {}` denies everything for the workloads it selects, and that default-deny is created by the first `ALLOW` policy rather than switched on.
- The three parts of a rule — `from.source`, `to.operation`, `when` — and that every part present must match while lists inside one part are ORed.
- `principals`, `namespaces` and `ipBlocks` as sources, and why `principals` cannot work without mTLS.
- That multiple `ALLOW` policies on one workload combine as a union, so adding policies can only permit more.
- The `CUSTOM` → `DENY` → `ALLOW` evaluation order, and that a `DENY` match ends the decision.
- What a workload selected only by `DENY` policies allows.
- `AUDIT` for testing a rule against live traffic without changing any response.
- Reading `notPaths` / `notMethods` / `notPrincipals` correctly, especially inside a `DENY`.
- Telling an authorization `403` apart from a transport-level connection reset.

---

## The Learning Path

### 1. Authorize HTTP Traffic Between Workloads
*   **Module Reader:** **[Module 1: Authorize HTTP Traffic Between Workloads](./module-01/course.md)**
    Deep-dive parts, in reading order:
    1. [How a request gets authorized](./module-01/course-01-how-a-request-is-authorized.md)
    2. [Default-deny and the allow-nothing policy](./module-01/course-02-default-deny-and-allow-nothing.md)
    3. [Rule anatomy: from, to, when](./module-01/course-03-rule-anatomy.md)
    4. [Identity rules, union semantics and debugging](./module-01/course-04-identity-union-and-debugging.md)
*   **Hands-on Playground:** `sections/section-020/module-01/playground` — namespace `authz-demo` with `booking-service` on its own service account, plus a `STRICT` `PeerAuthentication` already applied so identity rules can match. No authorization policy.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-01/playground
    ```
*   **Graded lab:** **[Lock A Namespace Down With ALLOW Policies](./module-01/labs/lab-01/)** — read the
    [exam question](./module-01/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-01
    astrona submit -c .
    ```

### 2. DENY Policies And Evaluation Order
*   **Module Reader:** **[Module 2: DENY Policies And Evaluation Order](./module-02/course.md)**
    Deep-dive parts, in reading order:
    1. [The evaluation pipeline](./module-02/course-01-the-evaluation-pipeline.md)
    2. [Writing DENY rules](./module-02/course-02-writing-deny-rules.md)
    3. [AUDIT, and choosing between ALLOW and DENY](./module-02/course-03-audit-and-design.md)
*   **Hands-on Playground:** `sections/section-020/module-02/playground` — namespace `deny-demo`, same shape, with a service that deliberately has no `/admin` handler so "blocked" and "reached the app" are easy to tell apart.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-02/playground
    ```
*   **Graded lab:** **[Close A Path With DENY](./module-02/labs/lab-01/)** — read the
    [exam question](./module-02/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-01
    astrona submit -c .
    ```

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.

---

## Capstone

**[Authorization Policy Capstone](./capstone/labs/lab-01/)** — One namespace, deny-by-default, identity-scoped ALLOW rules, and a DENY backstop that survives a careless future ALLOW.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/capstone/labs/lab-01
astrona submit -c .
```
