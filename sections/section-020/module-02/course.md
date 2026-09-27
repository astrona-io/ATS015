# DENY Policies And Evaluation Order

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-020/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-02/playground
> astrona destroy ats-015-playground-020-02
> ```

[Module 1](../module-01/course.md) built permissions out of `ALLOW` policies, which combine as a union — more policies, more permitted. Sooner or later someone needs the opposite: *this path is closed, whatever else anyone wrote.* That is `DENY`, and its whole behaviour comes from where it sits in the evaluation order.

Exam questions about authorization are disproportionately questions about that order, usually phrased as "an ALLOW and a DENY both match — what happens?" The answer never changes, and the reasoning is worth having rather than the flashcard.

## How this module is organised

1. **[Part 1 — The evaluation pipeline](./course-01-the-evaluation-pipeline.md)** — the three policy groups, the order they run in, what ends the decision, and the two defaults that follow from it.
2. **[Part 2 — Writing DENY rules](./course-02-writing-deny-rules.md)** — the object, prefix matching, negated conditions, and why an `ALLOW` cannot carve an exception out of a `DENY`.
3. **[Part 3 — AUDIT, and choosing between ALLOW and DENY](./course-03-audit-and-design.md)** — testing a rule against live traffic without enforcing it, and which of the two designs a given requirement wants.

## Learning objectives

After this module you can:

- State the order in which `CUSTOM`, `DENY` and `ALLOW` policies are evaluated, and what ends the decision at each step.
- Predict the outcome when an `ALLOW` and a `DENY` policy both match the same request.
- Say what a workload selected only by `DENY` policies permits, and why it differs from one selected by an `ALLOW`.
- Write a `DENY` rule with correct prefix matching, and explain why an exact path leaves a hole.
- Read `notPaths`, `notMethods` and `notPrincipals` correctly, especially inside a `DENY`.
- Use `AUDIT` to test a rule against live traffic without changing any response, and say where the result appears.
- Choose between an `ALLOW`-based and a `DENY`-based design for a given requirement, and explain how the two compose.

## Before you start

You need [Module 1](../module-01/course.md): `AuthorizationPolicy` structure (`selector`, `action`, `rules`), the `from` / `to` / `when` parts of a rule, and the rule that the first `ALLOW` policy selecting a workload creates default-deny. This module adds one field value — `action: DENY` — and spends the rest of its time on consequences.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and one injected namespace:

- **`deny-demo`** — `booking-service-v1` (service account `booking-sa`), `notification-service-v1` and a `tester` client pod. `notification-service` serves `POST /notify`; it has **no `/admin` handler**, which is useful here because you will be testing whether requests are *blocked*, not whether they are served.
- A **`PeerAuthentication` in `STRICT` mode**, applied at bootstrap, so identities are verifiable.

No `AuthorizationPolicy` exists yet.
