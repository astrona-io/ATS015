# Hand-over: 030-01 Authenticate End Users With JWT

Drafted without a cluster. The verify agent runs everything, replaces each
`<!-- OUTPUT PENDING: ... -->` with real output, writes `astrona.yaml` and the
section README lines below, then deletes this file.

## Playground

- Name: `ats-015-playground-030-01` (path `sections/section-030/module-01/playground`).
- Installs: kind cluster, Istio 1.30.5 with Helm (`istio-base` + `istiod` only, no gateway),
  namespace `starfleet` (injection on), mesh-wide access logs (`Telemetry mesh-default`),
  the full Starfleet (bridge, cargo, scout v1-v3, navcom), `shuttle`, `probe` v1/v2.
  No port forward. No RequestAuthentication / AuthorizationPolicy.
- Needs outbound internet (learner downloads `demo.jwt`, istiod downloads `jwks.json`).
- Fleet manifests copied from ATS014 010-01 playground; only the comment in `probe.yaml` was changed.
- Old `bootstrap/prepare.sh` and `manifests/lab-start.yaml` deleted.
- `examples/01-require-a-token/`: 01 RequestAuthentication `probe-jwt` (with `forwardOriginalToken: true`),
  02 AuthorizationPolicy `probe-require-jwt` (ALLOW, `requestPrincipals: ["*"]`),
  `cases/c1` (`fromParams: [token]`), `cases/c2` (DENY + `notRequestPrincipals`).
- Helpers (landing page and `docs/overview.md`): `SAMPLES_URL`, `TOKEN`, `AUTH`, `PROBE=http://probe:8000`,
  `check_status` (3 signals from the shuttle, prints `200 200 200 `).

## OUTPUT PENDING locations, in run order

Run in one playground, in this order (each part builds on the state the part before left):

1. `course-01-two-identities-on-one-signal.md` - decode `$TOKEN` payload (JSON with exp, foo, iat, iss, sub).
2. `course-01-two-identities-on-one-signal.md` - `kubectl get requestauthentication,authorizationpolicy -n starfleet` + two `check_status` lines (No resources found; 200 x3; 200 x3).
3. `course-02-check-the-token.md` - after applying `requestauthentication-probe.yaml`: no token / broken / valid (200, 401, 200).
4. `course-02-check-the-token.md` - `curl -H "$AUTH $TOKEN" $PROBE/headers` (JSON showing the Authorization header, because of `forwardOriginalToken: true`; trim the token in the output and say so).
5. `course-02-check-the-token.md` - `istioctl proxy-config listener deploy/probe-v1 ... | grep -i 'jwt_authn\|"issuer"' | head` (jwt_authn filter name + issuer line).
6. `course-03-require-a-token.md` - after applying `authorizationpolicy-probe-require-jwt.yaml`: 403, 401, 200.
7. `course-03-require-a-token.md` - response bodies: `RBAC: access denied` and the `Jwt ...` message for `Bearer broken`.
8. `course-03-require-a-token.md` - `istioctl analyze -n starfleet` (expected clean).
9. `course-04-other-token-places-and-deny.md` - after applying the `fromParams` RequestAuthentication: query token / header token / `?token=broken` (200, 403, 401).
10. `course-04-other-token-places-and-deny.md` - after re-applying `requestauthentication-probe.yaml` and applying the DENY policy: 403, 401, 200.
11. `course-05-wrap-up.md` - final `astrona list` after destroy ("No astrona labs running.").
12. `playground/docs/practice.md` task 1 - start from a clean playground (`kubectl delete requestauthentication,authorizationpolicy --all -n starfleet`): 403 / 401 / 200 / cargo 200.
13. `playground/docs/practice.md` task 2 - 200 (demo token) / 403 (no token).
14. `labs/lab-01/solution.md` - `booking: 200` after both objects.
15. `labs/lab-01/solution.md` - `istioctl proxy-config listener deploy/notification-service-v1 -n jwt-demo ...` grep.
16. `labs/lab-02/solution.md` - before any object: 200, 200.
17. `labs/lab-02/solution.md` - after both objects: 200, 403, 401, 403.

`labs/lab-01/solution.md` steps 1, 2 and 4 reuse the real output from the old
step-by-step guide (same app, same commands). Re-check them while running the lab.

## Labs

| Path | `metadata.name` | New? | App |
| --- | --- | --- | --- |
| `labs/lab-01` | `ats-015-lab-030-01` | converted | its own: `jwt-demo` with `notification-service`, `booking-service`, `tester` |
| `labs/lab-02` | `ats-015-lab-030-01-02` | **new** | Starfleet: `probe` v1/v2 + `shuttle` in `starfleet` |

- lab-01: install changed from `istioctl install --set profile=demo` to Helm (`istio-base` + `istiod`), like ATS014. The app needs no gateway. Old `validation.checks` (resourceExists RA and AP) are already checks 1 and 2 of the script. Added a `wait_for_policy` loop (up to 90 s until no-token gives 403) before grading. `docs/`, `teardown/`, `manifests/`, `bootstrap/setup.sh`, old `validate.sh` and `solution/*.yaml` removed; manifest now `bootstrap/manifests/jwt-demo.yaml`.
- lab-02 (new, build): RequestAuthentication `probe-jwt` with `fromParams: [token]`, AuthorizationPolicy `probe-require-jwt` with `action: DENY` + `notRequestPrincipals: ["*"]`, no ALLOW policy. Grader checks objects and four live signals (query 200, header 403, `?token=bad` 401, none 403).
- Both: `astrona validate` passes except the known `metadata.docs.question/solution` complaint (CLAUDE.md says keep those names). Neither lab has been through `astrona test` yet.

## astrona.yaml entries for this module

Replace the current 030-01 block (landing, three old parts, Question + lab) with:

```yaml
      - type: reading
        title: "Authenticate End Users With JWT"
        path: sections/section-030/module-01/course.md
      - type: reading
        title: "Two Identities On One Signal"
        path: sections/section-030/module-01/course-01-two-identities-on-one-signal.md
      - type: reading
        title: "Check The Token With RequestAuthentication"
        path: sections/section-030/module-01/course-02-check-the-token.md
      - type: reading
        title: "Require A Token"
        path: sections/section-030/module-01/course-03-require-a-token.md
      - type: reading
        title: Question
        path: sections/section-030/module-01/labs/lab-01/question.md
      - type: lab
        title: "Require A Valid End-User Token Lab"
        path: sections/section-030/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 20m
        topic: authentication
        task_kind: build
        tags: [requestauthentication, authorizationpolicy, jwt, request-principals, 401-vs-403]
        learning_goals:
          - Check end-user tokens on one workload with a RequestAuthentication
          - Make a token required with requestPrincipals in an ALLOW AuthorizationPolicy
          - Tell a 401 from the token check apart from a 403 from the policy
        resources:
          - name: "RequestAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/request_authentication/
          - name: "AuthorizationPolicy Source reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source
          - name: "JWT token authentication task"
            url: https://istio.io/latest/docs/tasks/security/authentication/jwt-route/
      - type: reading
        title: "Other Token Places And The DENY Form"
        path: sections/section-030/module-01/course-04-other-token-places-and-deny.md
      - type: reading
        title: Question
        path: sections/section-030/module-01/labs/lab-02/question.md
      - type: lab
        title: "Take The Token From The Query String Lab"
        path: sections/section-030/module-01/labs/lab-02
        difficulty: intermediate
        estimated_duration: 20m
        topic: authentication
        task_kind: build
        tags: [requestauthentication, authorizationpolicy, jwt, from-params, deny-policy, 401-vs-403]
        learning_goals:
          - Read the end-user token from a query parameter with fromParams
          - Require a token with a DENY policy that uses notRequestPrincipals
          - Explain why a token in the ignored header gets 403 and not 401
        resources:
          - name: "RequestAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/request_authentication/
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Authorization with JWT task"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-030/module-01/course-05-wrap-up.md
```

`topic` and `tags`: the lists in `CLAUDE.md` are the ATS014 traffic lists and have no security values. `authentication` and the tags `requestauthentication`, `authorizationpolicy`, `jwt`, `request-principals`, `from-params`, `deny-policy`, `401-vs-403` are proposals. The maintainer (or whoever owns `CLAUDE.md`) must add them to the lists first, or pick existing values. Check the resource URLs load.

## Section README lines to update (`sections/section-030/README.md`, module 1 block)

```markdown
### 1. Authenticate End Users With JWT
*   **Module Reader:** **[Module 1: Authenticate End Users With JWT](./module-01/course.md)**
    Deep-dive parts, in reading order:
    1. [Two Identities On One Signal](./module-01/course-01-two-identities-on-one-signal.md)
    2. [Check The Token With RequestAuthentication](./module-01/course-02-check-the-token.md)
    3. [Require A Token](./module-01/course-03-require-a-token.md)
    4. [Other Token Places And The DENY Form](./module-01/course-04-other-token-places-and-deny.md)
    5. [Wrap-Up](./module-01/course-05-wrap-up.md)
*   **Hands-on Playground:** `sections/section-030/module-01/playground`: the Starfleet on the planet `starfleet`, with the echo `probe` you protect and the `shuttle` you send signals from. No security objects yet, so you can watch a signal without a token get in before and after each object.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-01/playground
    ```
*   **Graded labs:**
    - **[Require A Valid End-User Token](./module-01/labs/lab-01/)**: check tokens, require one, tell 401 from 403 (own small app, `jwt-demo`).
    - **[Take The Token From The Query String](./module-01/labs/lab-02/)**: `fromParams` and "token required" as a `DENY` policy (Starfleet).
```

Also in that README: the "What You Will Master" list could gain a line for `fromParams` / `fromHeaders` and the `DENY` + `notRequestPrincipals` form, and the old links to `docs/exam-question.md` no longer exist.

## new-data files used (delete after verification)

- `new-data/securing-workloads/examples/03-jwt-authentication/01-requestauthentication-httpbin.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/02-authorizationpolicy-httpbin-require-jwt.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/cases/c1-requestauthentication-token-in-query.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/cases/c2-authorizationpolicy-deny-without-token.yaml`
- Shared, delete only after 030-02 is done: `examples/03-jwt-authentication/README.md` (JWT sections, two-resources diagram, 401/403 table, pitfalls), `examples/03-jwt-authentication/bootstrap/`, `config.yaml`.
- Not used here: `examples/03-jwt-authentication/PRACTICE.md`. Its only task (claim `foo: bar` with a `when` condition) is about claims, so it belongs to 030-02. This module's `docs/practice.md` has two new tasks (require a token on the probe only; one exact request principal).
- From `new-data/securing-workloads/README.md`: section 3 point 2 (RequestAuthentication before the policy, reverse to remove) went into `course-03`; the 401 and 403 rows of section 5 went into `course-03`. That README is shared with other modules.

## Space analogies chosen (not in the CLAUDE.md glossary)

JWT = a signed **crew pass**; issuer = the station that issues passes; JWKS = the station's
public **seal book**; `RequestAuthentication` = the **pass inspector** (checks any pass shown,
never asks for one); `AuthorizationPolicy` = the ship's **boarding list**. Align with 030-02
and 020-xx if they picked other pictures.

## Open doubts to check on the cluster

1. `istiod` (not the proxy) downloads the JWKS in 1.30.5 by default, and an unreachable `jwksUri` makes every token get `401`. `course-02` states this and shows a sequence diagram. Confirm (for example the `istiod` log, or inline `local_jwks` in `proxy-config listener`).
2. The exact `401` body for `Authorization: Bearer broken` (and `invalid` in lab-01). The placeholder guesses "Jwt is not in the form of Header.Payload.Signature...".
3. The 45-second wait after each apply (from new-data). Check whether it is really needed in this setup; if changes land in a few seconds, soften the TIP in `course-02` and the "Wait about 45 seconds" lines.
4. The grep pattern `'jwt_authn\|"issuer"'` on `proxy-config listener -o json` really prints both lines (the issuer may also appear inside the inlined JWKS provider block).
5. With `fromParams: [token]`, a valid token in the `Authorization` header gives `403` (not `401`). new-data says it was checked; confirm with the probe.
6. Re-applying `requestauthentication-probe.yaml` after the `fromParams` version removes `fromParams` (three-way merge through the last-applied annotation). `course-04` relies on it.
7. lab-01 now installs Istio with Helm instead of the `demo` profile. Run `astrona test` to confirm the grader (with the new `wait_for_policy` loop) still passes. Run `astrona test` on lab-02 too.
8. `kubectl exec ... curl -s $PROBE/headers` with the token: the echoed header name may be `Authorization` with a list value (go-httpbin format). Trim the long token in the output and say so.
