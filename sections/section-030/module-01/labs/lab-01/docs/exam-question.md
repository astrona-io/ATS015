# Exam Question: LAB015-030-01 — Require A Valid End-User Token

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile). Namespace `jwt-demo` is injected and
running `booking-service-v1`, `notification-service-v1` (serving `POST /notify`)
and a `tester` client pod.

No [`RequestAuthentication`](https://istio.io/latest/docs/reference/config/security/request_authentication/) and no [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) exist.

Istio publishes a demo issuer you will use:

- **issuer:** `testing@secure.istio.io`
- **JWKS:** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`
- **a valid token:** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt`

## Task

Protect `notification-service` so that it can only be called with a valid
end-user token from that issuer.

1. Configure token **validation** for the demo issuer, on `notification-service`
   only.
2. Make a token **mandatory**: a request with no `Authorization` header must be
   refused.

The observable result, all from `tester` calling `POST /notify`:

| Request | Expected |
| --- | --- |
| no `Authorization` header | `403` |
| `Authorization: Bearer invalid` | `401` |
| `Authorization: Bearer <the demo token>` | `200` |

Those two failure codes are different on purpose. If you get `403` for the bad
token, or `401` for the missing one, something is wrong.

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not restrict the objects to a namespace-wide scope — they must select
  `notification-service`.
- `booking-service` must remain callable without a token.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor fetches the demo token itself and sends all three requests.

When finished:

```sh
astrona destroy ats-015-lab-030-01
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [RequestAuthentication API](https://istio.io/latest/docs/reference/config/security/request_authentication/) — JWT issuers, JWKS and what it does not do
- [Authorization with JWT](https://istio.io/latest/docs/tasks/security/authentication/jwt-route/) — validating tokens and authorizing on their claims
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
