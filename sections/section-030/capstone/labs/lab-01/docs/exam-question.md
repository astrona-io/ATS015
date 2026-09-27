# Exam Question: CAP015-030 — End-User Authentication Capstone

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task, three parts)

---

## Context

A `kind` cluster with Istio 1.30.5 (`demo` profile). Namespace
`jwtclaims-demo` is injected and running `booking-service-v1`,
`notification-service-v1` and a `tester` client pod.

**Nothing is configured** — no `RequestAuthentication`, no
`AuthorizationPolicy`. Unlike the module lab, token validation is part of the
task here.

`notification-service` serves `POST /notify` and has **no `/admin`
handler**, so an authorized `/admin` request returns `404` from the
application. Anything that is not `403` means the mesh let it through.

The demo issuer:

- **issuer:** `testing@secure.istio.io`
- **JWKS:** `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`
- **plain token** (no `groups` claim): `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt`
- **groups token** (`groups: ["group1","group2"]`): `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/groups-scope.jwt`

Both tokens share the same `iss` and `sub`, so they produce the same request
principal. Only their claims differ.

## Task

On `notification-service`, combining both modules of the section:

1. **Validate** tokens from the demo issuer.
2. **Require** one: a request with no `Authorization` header may do nothing.
3. **Split access by claim:** any valid token may `POST /notify`; only a token
   whose `groups` claim contains `group1` may `GET /admin`.

The observable result, from `tester`:

| Request | Expected |
| --- | --- |
| no token, `POST /notify` | `403` |
| `Bearer invalid`, `POST /notify` | `401` |
| plain token, `POST /notify` | `200` |
| plain token, `GET /admin` | `403` |
| groups token, `GET /admin` | not `403` |
| no token, `GET /admin` | `403` |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Both rules must require a valid token, not merely test a claim.
- `booking-service` must remain callable without a token.

## How you will be graded

```sh
astrona submit -c .
```

When finished:

```sh
astrona destroy ats-015-capstone-030
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
