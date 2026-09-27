# Authorize HTTP Traffic Between Workloads

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-020/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-020/module-01/playground
> astrona destroy ats-015-playground-020-01
> ```

Mutual TLS proves that a caller is *someone in the mesh*. It has no opinion about whether that someone should be calling this service, on this path, with this method. A meshed workload from an unrelated team satisfies `STRICT` perfectly and can still call anything.

`AuthorizationPolicy` is where you say who may do what. Its most important behaviour is not a field at all: the moment the first `ALLOW` policy selects a workload, everything that policy does not permit becomes denied. Default-deny is something you create, not something you switch on.

## How this module is organised

1. **[Part 1 — How a request gets authorized](./course-01-how-a-request-is-authorized.md)** — where the decision happens, what compiles a policy into a filter, and why a workload with no policy allows everything.
2. **[Part 2 — Default-deny and the allow-nothing policy](./course-02-default-deny-and-allow-nothing.md)** — what `spec: {}` does field by field, and the rule that the first `ALLOW` closes the door.
3. **[Part 3 — Rule anatomy: from, to, when](./course-03-rule-anatomy.md)** — the three parts of a rule, and exactly how lists, parts and rules combine.
4. **[Part 4 — Identity rules, union semantics and debugging](./course-04-identity-union-and-debugging.md)** — `principals` and its dependence on mTLS, why more `ALLOW` policies permit more, and how to tell a wrong rule from one that never arrived.

## Learning objectives

After this module you can:

- Name the component that enforces authorization, say which side of the connection it runs on, and explain why a denial is visible there and not to the caller.
- Explain what an `AuthorizationPolicy` with an empty `spec: {}` does, field by field, and why it is the idiomatic deny-by-default baseline.
- State the rule that creates default-deny, and predict what a workload with no policies allows.
- Write `ALLOW` rules matching on `from.source`, `to.operation` and `when`, and say how lists, parts and rules each combine.
- Write a `principals` rule using a workload's real identity, and explain why it requires mTLS to match.
- Predict the result when two `ALLOW` policies select the same workload.
- Tell an authorization denial apart from a transport rejection, and a wrong rule apart from a policy that never reached the proxy.

## Before you start

You need mesh identity — the SPIFFE string derived from a service account — and `PeerAuthentication`, both from [section 010](../../section-010/README.md). Authorization on identity is only meaningful when identity is verified, so those two modules are genuinely load-bearing here rather than merely earlier.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and one injected namespace:

- **`authz-demo`** — `booking-service-v1` running as the service account **`booking-sa`**, `notification-service-v1` and a `tester` client pod, both running as **`default`**. All three listen on container port `8084`; `booking-service` serves `/book` and `notification-service` serves `/notify`.
- A **`PeerAuthentication` in `STRICT` mode** is already applied. That is a precondition rather than the subject: without it, `principals` rules cannot match.

No `AuthorizationPolicy` exists yet, which means every call in the namespace currently succeeds.
