# Part 1 — The evaluation pipeline

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Writing DENY rules](./course-02-writing-deny-rules.md).

Everything about `DENY` follows from one thing: where it runs relative to `ALLOW`. This part sets out the pipeline, derives the two defaults people misremember, and ends with a `403` produced for a reason that is *not* a `DENY` — so that the next part's identical-looking `403` means something you can distinguish.

## Three groups, one order

For every request, the receiving proxy's RBAC filter walks three groups of policies, in a fixed order:

```text
   request has reached stage 4 (the RBAC filter)
        │
        ▼
   ┌─────────────────────────────────────────────┐
   │ 1. CUSTOM policies selecting this workload  │
   │    delegate to an external authorizer       │
   │    (meshConfig.extensionProviders)          │
   └───────────────┬─────────────────────────────┘
                   │ rejected ─────────────▶ DENIED — stop
                   ▼ allowed / none present
   ┌─────────────────────────────────────────────┐
   │ 2. DENY policies selecting this workload    │
   └───────────────┬─────────────────────────────┘
                   │ any rule matches ─────▶ DENIED — stop
                   ▼ none matches
   ┌─────────────────────────────────────────────┐
   │ 3. ALLOW policies selecting this workload   │
   └───────────────┬─────────────────────────────┘
                   │
         does any ALLOW policy select this workload?
                   │
         no ───────────────────────────────▶ ALLOWED
                   │ yes
         does the request match a rule in one of them?
                   │
         yes ──────────────────────────────▶ ALLOWED
         no ───────────────────────────────▶ DENIED (403)
```

The critical structural property is that steps 1 and 2 are **terminal on a match**. They do not contribute a vote that step 3 can outweigh; they end the decision. Nothing downstream is consulted, and — importantly for [Part 3](./course-03-audit-and-design.md) — nothing downstream is even evaluated.

`CUSTOM` is included for completeness and appears rarely: it hands the decision to an external service, configured as an extension provider, which is how an existing external authorization system gets plugged into the mesh. It is worth recognising in a question about ordering; it is not worth studying further at this level.

## The two defaults people get backwards

Both fall directly out of step 3, and they fall out in opposite directions:

**A workload with no policies at all allows everything.** No `ALLOW` policy selects it, so the "must match" condition never applies. (This is [Module 1, Part 2](../module-01/course-02-default-deny-and-allow-nothing.md)'s rule, restated.)

**A workload with only `DENY` policies allows everything that is not explicitly denied.** Read step 3 again: the question is whether any *`ALLOW`* policy selects the workload. A `DENY` policy is not an `ALLOW` policy, so the answer is still no, so the request is allowed. Adding a `DENY` does **not** create default-deny.

That second one is the single most reliable way to be caught out. The instinct is that adding a security policy makes a workload more locked down in general, and here it makes it more locked down in exactly one respect and not at all in any other.

Put the two objects side by side and the asymmetry is the whole lesson:

| The workload is selected by… | Result |
| --- | --- |
| nothing | everything allowed |
| only `DENY` policies | everything allowed *except* what they match |
| any `ALLOW` policy | only what the `ALLOW` policies match |
| both | `DENY` matches lose immediately; the rest is decided by the `ALLOW` set |

## And therefore: DENY beats ALLOW

Because step 2 is terminal, **a `DENY` match ends the decision regardless of any `ALLOW`.** Not "usually". Not "unless the `ALLOW` is more specific" — specificity is not a concept in this model at all. There is no scoring, no longest-match, no narrowest-wins. There is an ordered walk, and the first terminal verdict is the answer.

Compare with `PeerAuthentication` from [section 010](../../section-010/module-02/course-02-scopes-and-precedence.md), where narrowest scope wins and a *more specific* `PERMISSIVE` genuinely overrides a broader `STRICT`. Two Istio security objects, two completely different resolution models. Knowing which model you are in is most of answering an ordering question correctly.

## A 403 that is not a DENY

Before writing any `DENY`, it is worth producing the other kind of `403` — the step-3 kind — so that the two are distinguishable later. Start from the shape of [Module 1](../module-01/course.md): an `ALLOW` that permits the intended call, which by existing also closes everything else on that workload.

> [!TIP]
> **Try it — the ALLOW baseline, and a 403 from step 3**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: allow-notify
>   namespace: deny-demo
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             namespaces: ["deny-demo"]
>       to:
>         - operation:
>             methods: ["POST"]
>             paths: ["/notify"]
> YAML
>
> kubectl -n deny-demo exec deploy/tester -- sh -c \
>   'curl -s -o /dev/null -w "POST /notify: %{http_code}\n" -X POST http://notification-service/notify;
>    curl -s -o /dev/null -w "GET  /admin:  %{http_code}\n" http://notification-service/admin'
> ```
>
> Expect something like:
>
> ```text
> POST /notify: 200
> GET  /admin:  403
> ```
>
> `/admin` is refused already — and nobody denied it. An `ALLOW` policy now selects this workload, `/admin` matches none of its rules, and step 3's last branch applies. Keep that in mind for [Part 2](./course-02-writing-deny-rules.md): the `DENY` you add there will produce an identical `403` for a completely different reason.

Which raises the practical problem this module comes back to twice: **the caller cannot tell the two apart.** Both are `403 RBAC: access denied`. The only way to know whether a request was refused by a `DENY` match or by failing to match any `ALLOW` is to look at the policy set on the callee — `kubectl get authorizationpolicy -A` and, when that is ambiguous, the compiled rules in the proxy.

> *Steps 1 and 2 are terminal on a match, so `DENY` does not outvote `ALLOW` — it ends the decision before `ALLOW` is ever read.*

## Reference

- [Istio authorization concepts](https://istio.io/latest/docs/concepts/security/#authorization-policies) — the evaluation order and the precedence statement in Istio's own words.
- [AuthorizationPolicy reference](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — the `ALLOW`, `DENY`, `AUDIT` and `CUSTOM` actions.
- [External authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-custom/) — what a `CUSTOM` policy delegates to, if you want to see step 1 in use.
