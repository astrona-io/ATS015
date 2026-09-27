# Authorize On JWT Claims

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-030/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-02/playground
> astrona destroy ats-015-playground-030-02
> ```

"A valid token exists" is a low bar. Every logged-in user clears it, including the ones who should never see the admin endpoint. Real end-user authorization asks what the token actually *says*: which user, in which groups, with which scopes.

Once a `RequestAuthentication` has validated a token, its claims become request attributes that an `AuthorizationPolicy` can match on. That is the whole mechanism, and the rest of this module is the syntax and the handful of ways it silently goes wrong.

## How this module is organised

1. **[Part 1 — Claims as request attributes](./course-01-claims-as-attributes.md)** — what the JWT filter publishes, the attribute names, and why you decode a real token before writing any rule.
2. **[Part 2 — `when` conditions and how they match](./course-02-when-conditions.md)** — the `when` block's combination rules, list claims, and what a missing claim does under each action.
3. **[Part 3 — Designing and debugging claim rules](./course-03-designing-and-debugging.md)** — one rule per role, reading the condition back off the proxy, and the pitfalls.

## Learning objectives

After this module you can:

- Name the request attributes a validated token exposes, including `request.auth.claims[...]` and its nested form.
- Decode a JWT payload and read the claim names an identity provider actually emits.
- Write a `when` condition matching a single-value claim and a list claim such as `groups`.
- Say whether multiple `when` entries, and multiple values within one entry, are ANDed or ORed.
- Explain what happens to a `when` condition when the claim is absent, under `ALLOW` and under `DENY`.
- Explain why every claim rule should also carry `requestPrincipals`.
- Read a compiled claim condition off the receiving proxy to tell a wrong claim name from a rule that never arrived.

## Before you start

You need [Module 1](../module-01/course.md): `RequestAuthentication` validates tokens but requires none, `requestPrincipals` in an `AuthorizationPolicy` is what makes a token mandatory, and the `jwt_authn` filter runs at stage 3 of the request pipeline, publishing attributes that authorization reads at stage 4. This module is entirely about that hand-off.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and one injected namespace:

- **`jwtclaims-demo`** — `booking-service-v1`, `notification-service-v1` (serving `POST /notify`, with **no `/admin` handler**) and a `tester` client pod.
- A **`RequestAuthentication`** for the Istio demo issuer is already applied, selecting `notification-service`. It is a precondition carried over from the previous module, not this module's subject.

No `AuthorizationPolicy` exists yet, so tokens are validated and nothing is required.

This module needs **outbound internet access**: you fetch two demo tokens, and the proxy fetches the issuer's keys.
