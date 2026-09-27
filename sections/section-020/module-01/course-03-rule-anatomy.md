# Part 3 — Rule anatomy: from, to, when

> Prerequisite: [Part 2 — Default-deny and the allow-nothing policy](./course-02-default-deny-and-allow-nothing.md). Next: [Part 4 — Identity rules, union semantics and debugging](./course-04-identity-union-and-debugging.md).

With the namespace closed, you reopen it one narrow rule at a time. A rule is three optional parts and a set of combination rules, and almost every policy that "looks right but does not work" is a misreading of how those parts combine. This part settles the algebra.

## The three parts

```yaml
  rules:
    - from:                       # who is calling
        - source:
            principals: [...]         mesh identity (from the client certificate)
            namespaces: [...]         the caller's namespace
            ipBlocks: [...]           the caller's address
            requestPrincipals: [...]  end-user identity from a JWT (section 030)
      to:                         # what they are doing
        - operation:
            methods: [...]            GET, POST, …
            paths: [...]              /book, /admin*, …
            ports: [...]              the destination port
            hosts: [...]              the Host header
      when:                       # anything else about the request
        - key: request.headers[x-api-version]
          values: ["v2"]
```

Each part draws its values from a different stage of [Part 1](./course-01-how-a-request-is-authorized.md)'s pipeline — `from.source.principals` from the mTLS handshake at stage 1, `to.operation` from the parsed HTTP at stage 2, `when` on `request.auth.*` from the JWT filter at stage 3. That is not trivia: it is why `principals` silently fails without mTLS and why token-based conditions need a `RequestAuthentication`.

## How things combine

Four levels, four different answers. Getting these straight is most of the skill:

```text
   values in one list        OR    methods: ["GET","POST"]     → either one matches
        │
   fields in one part       AND    methods + paths             → both must hold
        │
   parts in one rule        AND    from + to + when            → all present parts hold
        │
   rules in one policy       OR    rules: [ …, … ]             → any rule matching is enough
        │
   policies on one workload  OR    (covered in Part 4)
```

Read the middle two together and the most common mistake becomes visible: **a part that is absent is not a constraint**. Omitting `to.operation` means *any* operation, not *no* operation. A rule with only a `from` block permits that caller to do anything, which is rarely what someone writing a careful policy intended.

The mirror-image mistake is expecting a rule to be an intersection across rules. It is not: adding a second rule can only ever permit more traffic, never less. To express "this caller, but only these methods", both conditions go in **one** rule, as two parts.

Worth stating once because it reads oddly in YAML: `from` and `to` are lists whose entries are single-keyed objects (`- source:` / `- operation:`). Multiple `- source:` entries under one `from` are ORed, which is the idiomatic way to say "either of these two callers" without duplicating the whole rule.

## A rule, read out loud

The looser of the two rules this namespace needs lets anything in `authz-demo` book:

```yaml
spec:
  selector:
    matchLabels:
      app: booking-service
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces: ["authz-demo"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/book"]
```

Read it as one sentence, starting with the selector and ending with the consequence: *on the booking workloads, allow a caller from namespace `authz-demo` to POST `/book`* — and, because of [Part 2](./course-02-default-deny-and-allow-nothing.md)'s baseline, nothing else.

Saying it out loud is not a study gimmick. A policy that is hard to read aloud in one sentence is usually one where the parts do not combine the way its author assumed.

> [!TIP]
> **Try it — open exactly one door**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: booking-allow
>   namespace: authz-demo
> spec:
>   selector:
>     matchLabels:
>       app: booking-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             namespaces: ["authz-demo"]
>       to:
>         - operation:
>             methods: ["POST"]
>             paths: ["/book"]
> YAML
>
> kubectl -n authz-demo exec deploy/tester -- sh -c \
>   'curl -s -o /dev/null -w "POST /book:   %{http_code}\n" -X POST http://booking-service/book;
>    curl -s -o /dev/null -w "GET  /book:   %{http_code}\n" -X GET  http://booking-service/book'
> ```
>
> Expect something like:
>
> ```text
> POST /book:   200
> GET  /book:   403
> ```
>
> The method is a field in the `to` part, so changing it is enough to fall outside the rule — the two fields are ANDed. Note also what did *not* happen: this policy did not replace `allow-nothing`. Both select `booking-service`, and the request is allowed because it matched a rule in one of them.

## Path matching, exactly

`paths` is where policies quietly leave holes, because the matching is more literal than people expect. Three forms, and only three:

| Form | Matches | Does **not** match |
| --- | --- | --- |
| `/notify` | exactly `/notify` | `/notify/urgent`, `/notify2`, `/Notify` |
| `/notify*` | prefix: `/notify`, `/notify/urgent`, `/notify2` | `/api/notify` |
| `*/notify` | suffix: `/api/notify`, `/v1/notify` | `/notify/urgent` |

There is no regular-expression form and no partial wildcard in the middle. A `*` is only meaningful at the very start or the very end.

Two consequences worth holding:

- **An exact path in an `ALLOW` rule is usually too narrow** — `/book` alone rejects `/book/123`, and the application's 404 handler will not be what the caller reports.
- **An exact path in a `DENY` rule is usually too wide open** — blocking `/admin` leaves `/admin/users` reachable. That is [Module 2](../module-02/course.md)'s territory, and the reason its examples all use `/admin*`.

Matching is case-sensitive and operates on the path only — the query string is not part of it. When you need to condition on a query parameter or a header, that is `when`.

## `when`, briefly

`when` conditions match on request attributes that are not "who" or "what operation": headers, the destination IP, the connection's SNI, and — after a `RequestAuthentication` has run — everything about a validated token.

```yaml
      when:
        - key: request.headers[x-internal]
          values: ["true"]
```

Each entry takes a `key` and either `values` or `notValues`; entries are ANDed with each other and with the rest of the rule. That is the whole syntax. [Section 030](../../section-030/README.md) uses it heavily for JWT claims, which is where it earns its place; for workload-to-workload authorization, `from` and `to` carry most of the weight.

One caution that follows from stage ordering: a `when` condition on a header is only as trustworthy as the header. Anything the caller sets, the caller controls. Conditions on `request.auth.*` are different in kind, because a signature was checked before the attribute existed.

> *Values OR, fields AND, parts AND, rules OR — and a part you left out is not a constraint, it is a wildcard.*

## Reference

- [AuthorizationPolicy reference](https://istio.io/latest/docs/reference/config/security/authorization-policy/) — `Rule`, `Source`, `Operation` and `Condition`, field by field.
- [Authorization policy conditions](https://istio.io/latest/docs/reference/config/security/conditions/) — every valid `when` key and what it matches.
- [Authorization for HTTP traffic](https://istio.io/latest/docs/tasks/security/authorization/authz-http/) — worked rules with the path and method forms used here.
