# Exam Question: LAB015-030-02 — Authorize On A JWT Claim

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.examQuestion`.
> Meet the [prerequisites](./prerequisites.md) first.

**Task weight: 100%** (single scored task)

---

## Context

A `kind` cluster with Istio (`demo` profile). Namespace `jwtclaims-demo` is
injected and running `booking-service-v1`, `notification-service-v1` and a
`tester` client pod.

A **`RequestAuthentication`** for the demo issuer `testing@secure.istio.io` is
already applied to `notification-service` — token validation is a precondition
here, not the task. No `AuthorizationPolicy` exists.

`notification-service` serves `POST /notify` and has **no `/admin` handler**, so
an authorized `/admin` request returns `404` from the application. Anything that
is not `403` means the mesh let the request through.

Two tokens from the same issuer, with the same subject:

| Token | Claims |
| --- | --- |
| `.../release-1.30/security/tools/jwt/samples/demo.jwt` | no `groups` |
| `.../release-1.30/security/tools/jwt/samples/groups-scope.jwt` | `groups: ["group1","group2"]` |

## Task

On `notification-service`, write authorization so that:

1. **Any** request carrying a valid token may `POST /notify`.
2. **Only** a token whose `groups` claim contains `group1` may `GET /admin`.
3. A request with **no** token may do neither.

The observable result, from `tester`:

| Request | Expected |
| --- | --- |
| no token, `POST /notify` | `403` |
| demo token, `POST /notify` | `200` |
| demo token, `GET /admin` | `403` |
| groups token, `GET /admin` | not `403` (the app answers, with `404`) |

## Constraints

- Do not modify `config.yaml` or anything under `docs/`, `manifests/` or `solution/`.
- Do not change or delete the existing `RequestAuthentication`.
- Both rules must require a valid token, not merely test a claim.

## How you will be graded

```sh
astrona submit -c .
```

The Proctor fetches both tokens and sends all four requests.

When finished:

```sh
astrona destroy ats-015-lab-030-02
```

---

Want it walked through? See the [step-by-step guide](./step-by-step-guide.md).
Prefer hints over a full answer? See the [case study](./case-study.md).
