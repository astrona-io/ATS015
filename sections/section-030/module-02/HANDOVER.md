# Hand-over: 030-02 Authorize On JWT Claims (draft, no cluster run yet)

Delete this file after verification.

## Playground

- Name: `ats-015-playground-030-02` (path `sections/section-030/module-02/playground`).
- Installs: Istio 1.30.5 with Helm (`istio-base` + `istiod`, no gateways), namespace `starfleet` (injection on), mesh-wide access logs (`Telemetry mesh-default`), the Starfleet (`starfleet.yaml`), `shuttle`, `probe` v1/v2, and the precondition `RequestAuthentication probe-jwt` (selector `app: probe`, issuer `testing@secure.istio.io`, Istio release-1.30 sample `jwks.json`, `forwardOriginalToken: true`).
- No `portForwards` (no browser use in this module). `runtime: type: kind` only.
- Needs outbound internet (istiod fetches jwks; the reader fetches tokens).
- **Not deleted (needs the user):** `playground/bootstrap/prepare.sh`, `playground/manifests/lab-start.yaml`, `playground/manifests/requestauth.yaml` (and the `playground/manifests/` folder). My `rm -rf` of these was blocked by the permission classifier, and I was told not to retry. They are no longer referenced by `config.yaml`; delete them.

## OUTPUT PENDING locations, in run order

Run in the playground (paste the helper block from `course.md` first):

1. `course-01-read-what-the-token-says.md` line ~81: decode both tokens (two JSON payloads).
2. `course-01-read-what-the-token-says.md` line ~95: `curl -H "$AUTH $GROUPS_TOKEN" $PROBE/headers` (probe echo incl. `Authorization`; shorten the token and say so).
3. `course-02-require-a-claim.md` line ~56: apply `probe-require-jwt` (group rule) -> `created`.
4. `course-02-require-a-claim.md` line ~68: three `check_status` lines -> `403x3`, `200x3`, `403x3`.
5. `course-02-require-a-claim.md` line ~138: scope3 rule, groups token -> `403x3`.
6. `course-03-one-rule-per-role.md` line ~64: public path rule -> `200x3`, `403x3`, `200x3`.
7. `course-03-one-rule-per-role.md` line ~131: three-role policy, admin path -> `403x3`, `403x3`, `200x3`.
8. `course-04-debug-a-claim-rule.md` line ~76: typo rule (`group`), groups token -> `403x3`.
9. `course-04-debug-a-claim-rule.md` line ~92: `istioctl analyze -n starfleet` (expected clean).
10. `course-04-debug-a-claim-rule.md` line ~105: `istioctl proxy-config listener deploy/probe-v1 ... | grep -A3 'request.auth.claims'`.
11. `course-04-debug-a-claim-rule.md` line ~113: decode groups token.
12. `course-04-debug-a-claim-rule.md` line ~144: fixed rule -> `200x3` (groups), `403x3` (demo).
13. `playground/docs/practice.md` line ~52: Task 1 (`foo: bar`) -> `200x3`, `403x3`, `403x3` (expected values are also in the code comments; fix them if they differ).
14. `playground/docs/practice.md` line ~117: Task 2 (`probe-access`) -> `200x3`, `403x3`, `200x3`, `403x3`, `200x3`.
15. `course-05-wrap-up.md` line ~115: final `astrona list` after destroying everything.

Run in lab-01 (`ats-015-lab-030-02`):

16. `labs/lab-01/solution.md` line ~72: apply `jwt-claims` -> `created`.
17. `labs/lab-01/solution.md` line ~91: five-line `sh -c` curl block (see doubt 1 about `/admin`).

The token-decode output in `labs/lab-01/solution.md` Step 1 was kept from the old page (same tokens, same command, only the variable name changed). Check it anyway.

Run in lab-02 (`ats-015-lab-030-02-02`):

18. `labs/lab-02/solution.md` line ~27: two `send_signal` lines -> `403`, `403`.
19. `labs/lab-02/solution.md` line ~37: `kubectl get authorizationpolicy probe-access -o yaml` (shorten to spec).
20. `labs/lab-02/solution.md` line ~50: `proxy-config listener ... | grep -A3`.
21. `labs/lab-02/solution.md` line ~58: decode groups token.
22. `labs/lab-02/solution.md` line ~105: apply -> `configured`.
23. `labs/lab-02/solution.md` line ~120: six `send_signal` lines -> `200, 403, 200, 403, 403, 200`.

## Labs

| Lab | `metadata.name` | New? | App | Kind |
| --- | --- | --- | --- | --- |
| `labs/lab-01` Authorize On A JWT Claim | `ats-015-lab-030-02` (kept) | converted | own app (`jwtclaims-demo`: notification-service, booking-service, tester) | build |
| `labs/lab-02` Fix The Claim Rule | `ats-015-lab-030-02-02` | **new** | Starfleet planet: `shuttle`, `probe` v1/v2, `probe-jwt` RequestAuthentication | troubleshooting |

lab-01 changes: istioctl `demo` profile replaced by Helm `istio-base` + `istiod` (no ingress gateway was used). `validation.checks` (`resourceExists authorizationpolicy`) folded into the script as check 0. Two checks added so `question.md` matches the grader: the `jwt-demo` RequestAuthentication is unchanged (check 1), and every rule carries `requestPrincipals` (check 2b). Old `docs/`, `teardown/`, `validate.sh`, `bootstrap/setup.sh`, `solution/*.yaml` and `solution/README.md` were deleted; `manifests/` moved to `bootstrap/manifests/` (`requestauth.yaml` renamed to `requestauthentication-jwt-demo.yaml`).

lab-02 faults (seeded by `bootstrap/03-seed-fault.sh`): the `/headers` rule carries `requestPrincipals` (AND, so not public), and the admin rule compares `request.auth.claims[group]`.

`astrona validate` on both labs only complains about `metadata.docs.solution` / `question` (expected per CLAUDE.md). Playground validates clean. `astrona test` not run (no cluster allowed).

## astrona.yaml entries for this module

Replace the current 030-02 block (landing, three old parts, lab-01 question + lab) with:

```yaml
      - type: reading
        title: "Authorize On JWT Claims"
        path: sections/section-030/module-02/course.md
      - type: reading
        title: "Read What The Token Says"
        path: sections/section-030/module-02/course-01-read-what-the-token-says.md
      - type: reading
        title: "Require A Claim"
        path: sections/section-030/module-02/course-02-require-a-claim.md
      - type: reading
        title: "One Rule Per Role"
        path: sections/section-030/module-02/course-03-one-rule-per-role.md
      - type: reading
        title: Question
        path: sections/section-030/module-02/labs/lab-01/question.md
      - type: lab
        title: "Authorize On A JWT Claim Lab"
        path: sections/section-030/module-02/labs/lab-01
        difficulty: intermediate
        estimated_duration: 15m
        topic: jwt
        task_kind: build
        tags: [authorizationpolicy, requestauthentication, jwt-claims, when-conditions, request-principals, rbac-403]
        learning_goals:
          - Gate one path on a group claim with a when condition on request.auth.claims[groups]
          - Require a valid token in every rule with requestPrincipals, so a request without a token is refused everywhere
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Authorization policy conditions"
            url: https://istio.io/latest/docs/reference/config/security/conditions/
          - name: "Authorization with JWT"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/
      - type: reading
        title: "Debug A Claim Rule"
        path: sections/section-030/module-02/course-04-debug-a-claim-rule.md
      - type: reading
        title: Question
        path: sections/section-030/module-02/labs/lab-02/question.md
      - type: lab
        title: "Fix The Claim Rule Lab"
        path: sections/section-030/module-02/labs/lab-02
        difficulty: intermediate
        estimated_duration: 20m
        topic: jwt
        task_kind: troubleshooting
        tags: [authorizationpolicy, jwt-claims, when-conditions, request-principals, paths, proxy-config, rbac-403]
        learning_goals:
          - Find a claim name that no token carries by comparing the proxy's rule with a decoded token
          - Make one path public by giving it its own rule without a from block
          - Prove each path answers the right callers with live signals
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Authorization policy conditions"
            url: https://istio.io/latest/docs/reference/config/security/conditions/
          - name: "Authorization with JWT"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/
          - name: "Debugging Envoy and istiod"
            url: https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
      - type: reading
        title: "Wrap-Up"
        path: sections/section-030/module-02/course-05-wrap-up.md
```

`topic` and `tags` are taken from the ATS015 lists in `CLAUDE.md`.

## Section README lines to update (`sections/section-030/README.md`, module 2 block)

- Parts list: 1. Read What The Token Says (`course-01-read-what-the-token-says.md`), 2. Require A Claim (`course-02-require-a-claim.md`), 3. One Rule Per Role (`course-03-one-rule-per-role.md`), 4. Debug A Claim Rule (`course-04-debug-a-claim-rule.md`), 5. Wrap-Up (`course-05-wrap-up.md`).
- Playground line: "namespace `starfleet` with the Starfleet, `shuttle` and the `probe` echo service; a `RequestAuthentication` on the probe is already applied, so tokens are checked but none is required." (replaces `jwtclaims-demo`).
- Graded labs: "Authorize On A JWT Claim" (`labs/lab-01`, own small app) and new "Fix The Claim Rule" (`labs/lab-02`). Point at `question.md`, not `docs/exam-question.md`; submit with `astrona submit -c sections/section-030/module-02/labs/lab-0N`.
- The "What You Will Master" bullet "Why every claim rule should also carry requestPrincipals, or a tokenless request can slip past it" overstates it (see doubt 3); suggest: "Building one policy with one rule per role, including a public path, and pairing claim rules with `requestPrincipals`."

## new-data files used (delete after verification)

- `new-data/securing-workloads/examples/03-jwt-authentication/03-authorizationpolicy-httpbin-require-group.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/cases/c3-authorizationpolicy-require-scope3.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/cases/c4-authorizationpolicy-public-path.yaml`
- `new-data/securing-workloads/examples/03-jwt-authentication/PRACTICE.md` (the `foo: bar` task; it is the whole file, shared with 030-01 per the merge plan; delete only when 030-01 is done too)
- README.md sections "Requiring a claim", "Case 3", "Case 4" (the README is shared with 030-01).

## Open doubts to check on the cluster

1. **lab-01 `/admin` status.** The old page claimed `group1 /admin: 404`, but `notification-service`'s nginx config returns `200` for every location (`location / { return 200 ... }`). Expect `200`. The grader accepts anything but `403`, so it passes either way; the question no longer promises `404`.
2. **go-httpbin `/anything/admin`.** Assumed to answer `200` (go-httpbin v2.15.0 serves `/anything/*`). Every part and lab-02 rely on it. If it does not, switch to another `200` path such as `/status/200` and update the YAML everywhere.
3. **`when` without `requestPrincipals`.** The old text said a claim rule without `requestPrincipals` can be satisfied by a request with no token. I could not back that for `values` (no token means no claims, so the condition cannot fit), so the new text only says pairing makes the requirement explicit. Practice Task 1 (`when` only, `foo: bar`) expects no-token `403`; confirm. `notValues` on a missing claim was left out on purpose (unsure whether it fits); worth a quick test if you want to add it.
4. **`istioctl analyze` and a wrong claim name.** Assumed clean output (`course-04`, lab-02 "Common Mistakes").
5. **`proxy-config listener` grep.** Assumed the RBAC metadata matcher shows `"key": "request.auth.claims"` then `"key": "group"` within 3 lines; adjust the `-A` count if needed. Also check that `deploy/probe-v1` works for `istioctl proxy-config` (two probe pods).
6. **The 45-second wait.** Kept from new-data (old connections keep old rules during drain). Check whether results change immediately with `check_status`; if they do, soften the sentences in parts 2, lab-01 and lab-02 solution.
7. **`forwardOriginalToken: true`** in `probe-jwt` so `/headers` echoes the `Authorization` header (part 1). Confirm the header shows up.
8. **Helm install for lab-01.** The lab used the `demo` profile before; nothing in it needs the ingress gateway, but confirm `astrona test` passes.
