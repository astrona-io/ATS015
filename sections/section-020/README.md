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
    Parts, in reading order:
    1. [The Guard At The Airlock](./module-01/course-01-the-guard-at-the-airlock.md)
    2. [Close The Airlock](./module-01/course-02-close-the-airlock.md)
    3. [Write A Guest List Entry](./module-01/course-03-write-a-guest-list-entry.md)
    4. [Name The Caller](./module-01/course-04-name-the-caller.md)
    5. [Least Privilege For The Whole Fleet](./module-01/course-05-least-privilege-for-the-fleet.md)
    6. [Find Out Why The Guard Says No](./module-01/course-06-find-out-why-the-guard-says-no.md)
    7. [Wrap-Up: Mission Debrief](./module-01/course-07-wrap-up.md)
*   **Hands-on Playground:** `sections/section-020/module-01/playground`: the Starfleet on the planet `starfleet` with `STRICT` mTLS already on, the `shuttle`, `fortio` (a second caller with another badge) and the `probe`, plus the `drifter` on the planet `outpost` with no sidecar. No `AuthorizationPolicy` yet.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-01/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Lock A Namespace Down With ALLOW Policies](./module-01/labs/lab-01/README.md)**: read the [task](./module-01/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-01
        astrona submit -c sections/section-020/module-01/labs/lab-01
        ```
    *   **[Repair The Fleet's Guest Lists](./module-01/labs/lab-02/README.md)**: read the [task](./module-01/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-02
        astrona submit -c sections/section-020/module-01/labs/lab-02
        ```

### 2. DENY Policies And Evaluation Order
*   **Module Reader:** **[Module 2: DENY Policies And Evaluation Order](./module-02/course.md)**
    Deep-dive parts, in reading order:
    1. [The Guard Checks The Banned List First](./module-02/course-01-the-guard-checks-the-banned-list-first.md)
    2. [A Guest List Cannot Overrule The Ban](./module-02/course-02-a-guest-list-cannot-overrule-the-ban.md)
    3. [Lock Everything With One Empty Rule](./module-02/course-03-lock-everything-with-one-empty-rule.md)
    4. [Close The Whole Path](./module-02/course-04-close-the-whole-path.md)
    5. [Say It Out Loud: Negative Fields](./module-02/course-05-say-it-out-loud-negative-fields.md)
    6. [AUDIT, And Choosing ALLOW Or DENY](./module-02/course-06-audit-and-choosing-allow-or-deny.md)
    7. [Wrap-Up: Mission Debrief](./module-02/course-07-wrap-up.md)
*   **Hands-on Playground:** `sections/section-020/module-02/playground`: the Starfleet on the planet `starfleet` with `STRICT` mTLS already on. The `shuttle` and `fortio` are two callers with different ID badges, and the echo `probe` is the ship you protect. No `AuthorizationPolicy` yet.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-02/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Close A Path With DENY](./module-02/labs/lab-01/README.md)**: its own small app in the namespace `deny-demo`. Read the [task](./module-02/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-01
        astrona submit -c sections/section-020/module-02/labs/lab-01
        ```
    *   **[Make The Probe Read-Only](./module-02/labs/lab-02/README.md)**: the Starfleet. Read the [task](./module-02/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-02
        astrona submit -c sections/section-020/module-02/labs/lab-02
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
