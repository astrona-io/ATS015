# Part 2 — What ztunnel can enforce

> Prerequisite: [Part 1 — The ambient dataplane](./course-01-the-ambient-dataplane.md). Next: [Part 3 — Waypoints and L7 policy](./course-03-waypoints-and-l7-policy.md).

ztunnel terminates the HBONE tunnel, so it sees the peer certificate and the connection's addresses and ports — and nothing about the request inside. That one sentence partitions `AuthorizationPolicy`'s fields into two sets. This part is the set ztunnel can handle alone.

## The L4 field set

Everything decidable from the connection:

| Field | Available at L4 | Why |
| --- | --- | --- |
| `from.source.principals` | **yes** | read from the peer certificate on the HBONE connection |
| `from.source.namespaces` | **yes** | derived from the same identity |
| `from.source.ipBlocks` | **yes** | the connection's source address |
| `to.operation.ports` | **yes** | the destination port |
| `to.operation.methods` | no | needs the parsed request |
| `to.operation.paths` | no | needs the parsed request |
| `to.operation.hosts` | no | needs the `Host` header |
| `from.source.requestPrincipals` | no | needs a validated JWT |
| `when: request.headers[…]`, `request.auth.*` | no | needs the parsed request |

The dividing line is exactly the one from [section 020](../../section-020/module-01/course-01-how-a-request-is-authorized.md)'s pipeline: stage 1 (transport) inputs are available, stage 2 and 3 (HTTP, JWT) inputs are not. ztunnel implements stage 1 and stage 4's connection-level half, and stops.

Worth noticing how familiar that set is. It is the same list that survives in passthrough mode at a gateway ([section 040](../../section-040/module-03/course-03-what-passthrough-costs.md)), for the same reason: no key to the payload, or no intention of parsing it. Three different situations in this course, one identical capability boundary.

## Identity does not need a waypoint

This is the half of the story that gets lost. Because ztunnel does mTLS over HBONE with the ordinary mesh certificates, `principals` rules are fully enforceable with no L7 layer anywhere:

```yaml
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/ambient-authz/sa/tester-sa
```

Note this one uses a label `selector` — the same form as every policy in [section 020](../../section-020/README.md). For ztunnel-level L4 policy on workloads, that is the right attachment, and [Part 3](./course-03-waypoints-and-l7-policy.md) explains when it is not.

The identity string is unchanged from [section 010](../../section-010/module-01/course-03-principals-rotation-trust-domain.md): `<trust-domain>/ns/<namespace>/sa/<service-account>`, no `spiffe://`. Nothing about ambient mode changes how identity is issued, named or matched — only where it is checked.

The playground's two clients exist to make that visible: `tester` runs as `tester-sa`, `other-client` as `other-sa`, and they are otherwise identical `curl` pods.

> [!TIP]
> **Try it — identity-based L4 policy, no waypoint**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: notification-l4
>   namespace: ambient-authz
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             principals:
>               - cluster.local/ns/ambient-authz/sa/tester-sa
> YAML
>
> sleep 3
> kubectl -n ambient-authz exec deploy/tester -- \
>   curl -s -o /dev/null -w 'tester:       %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
> kubectl -n ambient-authz exec deploy/other-client -- \
>   curl -s -o /dev/null -w 'other-client: %{http_code}\n' --max-time 5 -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> tester:       200
> other-client: 000
> ```
>
> A `WAYPOINT: None` workload, from [Part 1](./course-01-the-ambient-dataplane.md), and the policy is enforced anyway — because everything this rule needs was available on the HBONE connection. `other-client` is refused for having the wrong service account, exactly as it would be in sidecar mode.

## An L4 denial is a connection error

Look at that `000` again. In sidecar mode an authorization denial is always `403`, because the rejection happens in an HTTP filter that can write a response. ztunnel has no HTTP layer, so it refuses the **connection**:

```text
   sidecar mode                        ambient, L4 denial (ztunnel)
   ────────────                        ────────────────────────────
   connection accepted                 connection refused
   request parsed                      nothing parsed
   RBAC filter says no                 ztunnel says no
   403 "RBAC: access denied"           connection reset  →  curl reports 000
```

That gives ambient mode a **three-way** failure vocabulary, where earlier sections had two:

| What you see | Refused by | Layer |
| --- | --- | --- |
| `000` / connection reset | ztunnel, or edge TLS, or `STRICT` `PeerAuthentication` | transport |
| `403` | a waypoint's RBAC filter | HTTP |
| `404` / anything else | nothing — the application answered | — |

So in an ambient namespace, the status code tells you *which component* made the decision before you read a single policy. `000` means an L4 rule fired and a waypoint was not involved; `403` means a waypoint was in the path and its L7 rule fired. That is a genuinely useful diagnostic and the reason this part insists on the distinction now, before [Part 3](./course-03-waypoints-and-l7-policy.md) introduces a second source of denials.

One practical consequence: **a client cannot tell an L4 denial from the service being down.** Both are connection failures. Where a caller needs to distinguish "you are not allowed" from "try again later", an L7 rule behind a waypoint gives them a `403` to act on, and that alone is sometimes reason enough to deploy one.

> *ztunnel enforces everything decidable from the connection — including identity — and refuses at the transport, so an L4 denial arrives as `000` rather than `403`.*

## Common pitfalls

> [!WARNING]
> **Writing an L7 rule and expecting ztunnel to apply it.** It cannot parse HTTP. The rule is accepted and silently unenforced.
>
> **Reading a policy as enforced because it exists.** In ambient the question is always *where* it is enforced, and by what.
>
> **Assuming identity is unavailable without a sidecar.** ztunnel does mTLS and carries identity; it is the L7 attributes it lacks.
>
> **Testing L4 policy with an HTTP-shaped test.** A 403 and a dropped connection mean different layers refused you.

## Reference

- [Ambient L4 authorization policy](https://istio.io/latest/docs/ambient/usage/l4-policy/) — which fields ztunnel supports and how it behaves without a waypoint.
- [AuthorizationPolicy `Source`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — the field definitions, for checking which side of the L4/L7 line a rule sits on.
- [Istio ambient architecture](https://istio.io/latest/docs/ambient/architecture/) — what ztunnel terminates and what it deliberately does not inspect.
