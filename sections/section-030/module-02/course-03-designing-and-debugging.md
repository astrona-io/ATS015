# Part 3 — Designing and debugging claim rules

> Prerequisite: [Part 2 — `when` conditions and how they match](./course-02-when-conditions.md). Next: [the module landing page](./course.md), then [Section 040 — Securing Edge Traffic With TLS](../../section-040/README.md).

The syntax is settled. What remains is the part that decides whether a claim-based policy survives contact with a real access model: how to lay the rules out so someone can read them, and how to tell a rule that is wrong from one the proxy never received.

## One policy, one rule per role

The policy in [Part 2](./course-02-when-conditions.md) has the shape to reuse: a single `ALLOW` policy per workload, whose rules correspond to roles.

```text
   AuthorizationPolicy: notification-access
     rule 1   any authenticated user      → POST /notify
     rule 2   groups includes group1      → GET  /admin
     rule 3   groups includes auditor     → GET  /reports
```

Rules within a policy are ORed, so each is a complete, independent statement of one role's access, and the policy as a whole is the workload's access model — readable top to bottom, in one object.

The alternative, one policy per role, produces the same behaviour and a worse artefact. To answer "who can reach `/admin`?" you must first find every policy whose `selector` matches this workload, anywhere in the namespace, and then read them together. Since [Module 1 of section 020](../../section-020/module-01/course-04-identity-union-and-debugging.md) established that policies combine as a union, missing one means being confidently wrong.

Two habits keep the pattern working:

- **Order rules from least to most privileged.** The evaluation does not care — it is an OR — but a reader does, and the rule that grants the most should be the one hardest to miss.
- **Keep the deny-by-default baseline separate.** The `allow-nothing` policy from [section 020](../../section-020/module-01/course-02-default-deny-and-allow-nothing.md) covers workloads nobody has written rules for yet. It is a namespace-level standing default, not part of any one service's access model.

## When a claim rule does nothing

A claim rule that silently fails to match has three candidate causes, and they need different fixes:

```text
   the claim name is wrong           → the rule compiled, matches nothing
   the RequestAuthentication is
     missing or selects nothing      → no attributes published at all
   the AuthorizationPolicy's
     selector matches no pod         → nothing compiled into this proxy
```

The first two both look like "the right user is being denied". The third looks like "the policy does nothing at all, for anyone". Reading the compiled configuration separates them in one command.

> [!TIP]
> **Try it — find the claim condition in the proxy's configuration**
>
> ```sh
> istioctl proxy-config listener deploy/notification-service-v1 -n jwtclaims-demo -o json \
>   | grep -i 'request.auth.claims' -A3 | head
> istioctl analyze -n jwtclaims-demo
> ```
>
> Expect something like:
>
> ```text
>                                  "key": "request.auth.claims",
>                                  "value": "groups",
> ✔ No validation issues found when analyzing namespace: jwtclaims-demo.
> ```
>
> The exact JSON shape varies between Istio versions, so treat the output as an example. What you are checking is that the claim name you wrote is the one the proxy is matching on — a typo here produces a rule that is syntactically perfect and never true. No output at all means the policy's `selector` matched no pod, which is a different problem entirely. Pair it with `istioctl proxy-config listener … | grep jwt_authn` from [Module 1](../module-01/course-03-requiring-a-token.md) to confirm the validating filter is there too.

Then the decisive test, which costs nothing: **take a token that is being denied and decode it.** Compare its claim names and values against the rule, character by character. That comparison — between two things you can both see — settles in seconds what reasoning about the policy can take an afternoon to guess at.

Claim rules go wrong in a small number of specific ways, and most of them produce no error.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **Treating a list claim as a string** — `values: ["group1"]` already matches any element of `groups`. There is no list syntax to find.
>
> **Using the identity provider's display name for a claim** — decode a real token and read the payload.
>
> **Expecting a missing claim to be permissive** — under `ALLOW` a missing claim fails the condition and the request is denied; under `DENY` it fails open.
>
> **`when` without `requestPrincipals`** — the rule can then be satisfied by a request with no token at all.
>
> **Writing a claim rule with no `RequestAuthentication` on the workload** — no attributes are published, so nothing can ever match.
>
> **Reading `404` or `200` as "the policy failed"** — anything that is not `403` means the request got through. Test against an endpoint whose behaviour you know.
>
> **Quoting `$TOKEN` inside single quotes in `kubectl exec`** — the variable never expands and every request looks like a bad token.
>
> **Expecting `values: ["a","b"]` to require both** — values inside one entry are ORed. Two requirements need two `when` entries.

## The boundary worth keeping

Two habits make claim-based rules hold up in a real system, and both are about not over-trusting what the mesh can check.

**Decode before you write.** Every rule here is a string comparison against a value another system produced. Reading one real token tells you the claim names, whether a value is a string or a list, and whether the issuer prefixes anything. Guessing costs more than looking, every time.

**Remember what a signature proves.** Istio verifies that the issuer signed these claims and that the token has not expired. It does not know whether the user still belongs in `group1`, whether the token was stolen, or whether the issuer's group membership was revoked ten minutes ago. Those are the identity provider's responsibilities, and the mesh's enforcement is only ever as current as the token lifetime allows.

Which is the honest summary of this whole section: Istio is a very good place to enforce *what the issuer said*, and not a place to decide *what is true*.

> *Keep one policy per workload with one rule per role, and settle every claim-rule mystery by decoding the denied token and comparing it to the compiled condition.*

## Reference

- [JWT claim-based authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/) — Istio's worked examples for claim rules.
- [Authorization policy conditions](https://istio.io/latest/docs/reference/config/security/conditions/) — the complete key list, for checking a name before you rely on it.
- [Security best practices](https://istio.io/latest/docs/ops/best-practices/security/) — Istio's own guidance on layering authentication and authorization.
