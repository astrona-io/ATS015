# Part 4 — Identity rules, union semantics and debugging

> Prerequisite: [Part 3 — Rule anatomy: from, to, when](./course-03-rule-anatomy.md). Next: [the module landing page](./course.md), then [Module 2 — DENY Policies And Evaluation Order](../module-02/course.md).

`namespaces` is a coarse control: it lets in anything that happens to run in the namespace. This part narrows to an exact workload identity, explains the mTLS dependency that makes such a rule work or silently fail, settles what happens when several policies select one workload, and ends with how to tell a wrong rule from a policy that never arrived.

## Matching an exact identity

```yaml
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/authz-demo/sa/booking-sa
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
```

The principal format is `<trust-domain>/ns/<namespace>/sa/<service-account>`, with no `spiffe://` prefix — the certificate SAN carries the scheme, the policy field does not. [Module 1 of section 010](../../section-010/module-01/course-03-principals-rotation-trust-domain.md) covers why, and how to read the correct value off a live certificate.

Two properties follow from where the value comes from, and both are worth being explicit about.

**`principals` requires mTLS.** Trace it back through [Part 1](./course-01-how-a-request-is-authorized.md)'s pipeline: the peer identity is extracted at stage 1, from the client certificate presented during the handshake. On a `PERMISSIVE` workload, a plaintext caller presents no certificate, so stage 1 produces no identity, so the rule at stage 4 has nothing to compare and cannot match. The request is denied — not because of who the caller is, but because the field the rule depends on is empty. That is why this playground applies `STRICT` before anything else, and why "my `principals` rule denies everything" is usually a `PeerAuthentication` problem rather than an authorization one.

**The rule is about the service account, not the pod.** `notification-service-v1` and `tester` both run as `default`, so they are one caller as far as any `principals` rule is concerned.

> [!TIP]
> **Try it — the same request, two identities**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: notification-allow
>   namespace: authz-demo
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             principals:
>               - cluster.local/ns/authz-demo/sa/booking-sa
>       to:
>         - operation:
>             methods: ["POST"]
>             paths: ["/notify"]
> YAML
>
> kubectl -n authz-demo exec deploy/booking-service-v1 -c booking-service -- \
>   curl -s -o /dev/null -w 'booking -> notify: %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n authz-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'tester  -> notify: %{http_code}\n' -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> booking -> notify: 200
> tester  -> notify: 403
> ```
>
> Identical request, identical namespace, identical method and path. The only difference is the certificate presented during the handshake — which is exactly the property mTLS was turned on to provide. Method still narrows further: `booking-sa` sending `GET /notify` is refused, because the `to` part does not match and no other rule does.

## Two policies on one workload

`booking-service` is now selected by two `ALLOW` policies: the namespace-wide `allow-nothing` and the specific `booking-allow`. `notification-service` is selected by `allow-nothing` and `notification-allow`.

The result is the **union**. A request is allowed if it matches a rule in *any* policy selecting the workload:

```text
   allow-nothing        rules: []            ──┐
   booking-allow        rules: [POST /book]  ──┼──▶  OR  ──▶  allowed if any matches
   (a third policy…)    rules: [...]         ──┘
```

This is the opposite of most people's first instinct, which is that adding a restrictive-looking policy restricts. It does not. **Adding `ALLOW` policies can only ever permit more.** The narrowing happened exactly once, when the first `ALLOW` policy appeared and took the workload from "everything" to "only what is listed" — the rule from [Part 2](./course-02-default-deny-and-allow-nothing.md).

Contrast that with `PeerAuthentication`, which selects a single winner by narrowest scope. Two different objects, two different combination rules, and mixing them up produces confident wrong answers in both directions:

| | multiple policies on one workload |
| --- | --- |
| `PeerAuthentication` | narrowest scope wins outright; the others are not consulted |
| `AuthorizationPolicy` (`ALLOW`) | union; every policy contributes its rules |

To actually subtract something, you need `DENY`, which is evaluated before `ALLOW` and is [Module 2](../module-02/course.md)'s subject.

## Telling a wrong rule from a missing one

When a policy appears to do nothing, there are exactly two possibilities, and they need different fixes:

1. the rules are wrong — the policy reached the workload and nothing matched;
2. the policy never selected the workload — a `selector` typo, the wrong namespace.

`kubectl get authorizationpolicy` cannot distinguish them: the object exists either way. The proxy can.

> [!TIP]
> **Try it — see the RBAC filter on the receiving proxy**
>
> ```sh
> kubectl -n authz-demo get authorizationpolicy
> istioctl proxy-config listener deploy/notification-service-v1 -n authz-demo -o json \
>   | grep -i 'rbac\|shadow_rules\|envoy.filters.http.rbac' | head
> ```
>
> Expect something like:
>
> ```text
> NAME                 AGE
> allow-nothing        6m
> booking-allow        4m
> notification-allow   1m
> envoy.filters.http.rbac
> "@type": "type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC"
> ```
>
> The filter's presence is evidence that at least one policy selecting this workload was compiled and pushed. If `kubectl get` lists your policy but the filter is absent, the `selector` matches no pod — usually a label typo — and no amount of editing the rules will help.

Two more tools complete the set:

**`istioctl analyze -n authz-demo`** catches typo-class problems before traffic does — a selector matching nothing, a referenced service account that does not exist, conflicting objects. Worth running after any security change.

**The callee's access log** shows the request and its response code together, which is the fastest way to confirm a `403` is yours rather than the application's:

```sh
kubectl -n authz-demo logs deploy/notification-service-v1 -c istio-proxy --tail=20
```

Most of what goes wrong here is a field doing something subtly different from what it looks like.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **Using `principals` without mTLS** — no verified identity means the rule never matches and the traffic is denied with no clue why. Check `PeerAuthentication` first.
>
> **Writing `spiffe://…` in `principals`** — the field takes the identity without the scheme, and the mismatch produces no error.
>
> **Expecting more `ALLOW` policies to restrict** — they combine as a union. To subtract, you need `DENY`.
>
> **Assuming an omitted `to.operation` means "nothing"** — an absent part is unconstrained. Only an absent `rules` list denies.
>
> **Splitting one intent across two rules** — "this caller, only these methods" is one rule with two parts, not two rules.
>
> **Confusing `403` with a connection reset** — `403 RBAC: access denied` is authorization at stage 4. `000` is the transport at stage 1, which means `PeerAuthentication`.
>
> **Exact paths where a prefix was meant** — `paths: ["/notify"]` does not match `/notify/urgent`.
>
> **Debugging from the caller** — the caller only learns that it got a `403`. The explanation is always on the callee.

## What this module leaves open

Three gaps, each closed by a later module rather than by more fields here:

- **Subtracting from an allowance.** `ALLOW` policies only add. [Module 2](../module-02/course.md).
- **Authorizing on the end user rather than the workload.** `requestPrincipals` and token claims. [Section 030](../../section-030/README.md).
- **Callers with no mesh identity at all** — anything arriving from outside. [Section 050](../../section-050/README.md).

> *`principals` matches a value extracted from the client certificate, so it needs mTLS to exist — and every `ALLOW` policy on a workload contributes to a union that can only ever permit more.*

## Reference

- [AuthorizationPolicy `Source`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `principals`, `namespaces`, `ipBlocks` and their negated forms.
- [Authorization policy precedence](https://istio.io/latest/docs/concepts/security/#implicit-enablement) — how policies selecting one workload combine.
- [`istioctl analyze`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-analyze) — the static checks that catch selector and reference mistakes.
