# Hand-over: 020-02 DENY Policies And Evaluation Order (draft, no cluster run)

Delete this file after verification.

## Playground

- Name: `ats-015-playground-020-02` (`playground/config.yaml`, kind runtime, no port forwards).
- `bootstrap/install-istio.sh`: Helm, Istio 1.30.5, `istio-base` + `istiod` only. Pins context `kind-astro-ats-015-playground-020-02`.
- `bootstrap/deploy.sh`: namespace `starfleet` (injection) + mesh access logs, `starfleet.yaml` (bridge, cargo, scout v1-v3, navcom), `shuttle`, `probe` v1/v2, `fortio` (runs as SA `default`), `outpost` with `drifter` (no sidecar), and `peerauthentication-strict.yaml` (`default`, `STRICT`, ns `starfleet`). No AuthorizationPolicy.
- Manifests copied from ATS014 (010-01 fleet files, 000-01 `outpost.yaml`, 040-02 `fortio.yaml`; fortio header comment rewritten like ATS015 010-01).
- `examples/01-deny-policies/`: 01 probe-deny-status, 02 probe-allow-shuttle-get, cases c1 deny-non-get, c2 allow-all, c3 deny-all.
- `docs/overview.md`, `docs/practice.md` (two DENY tasks written new, the new-data PRACTICE.md has no DENY task).
- Old `bootstrap/prepare.sh`, `manifests/lab-start.yaml`, `manifests/peerauth.yaml` deleted (staged with `git rm`).

## OUTPUT PENDING, in run order

Playground (one session; parts 3 to 6 each start with `kubectl delete authorizationpolicy --all -n starfleet`). Paste the landing-page helpers first.

1. `course-01-...md:52` baseline: shuttle /get and /status/200 all 200
2. `course-01-...md:86` apply probe-deny-status (capture any Warning about TCP ports exactly; if none, also delete the paragraph "If apply printed a warning about TCP ports...")
3. `course-01-...md:97` shuttle /get 200, /status/200 403; fortio /status/200 403, /get 200
4. `course-01-...md:127` body `RBAC: access denied` + probe log line with matched_policy for probe-deny-status
5. `course-02-...md:47` apply probe-allow-shuttle-get
6. `course-02-...md:58` shuttle /get 200, /status/200 403, POST /post 403; fortio /get 403
7. `course-02-...md:85` both bodies `RBAC: access denied` (check what `fortio curl -quiet ... | tail -1` really prints)
8. `course-02-...md:98` log lines: policy name vs `matched_policy[none]` (the `probe_guard_log 'GET /get'` grep may catch a shuttle 200 line; adjust the command if needed)
9. `course-02-...md:108` `kubectl get authorizationpolicy -n starfleet` table (real columns)
10. `course-03-...md:39` delete all policies
11. `course-03-...md:73` allow-all: all 200
12. `course-03-...md:109` deny-all + allow-all: all 403
13. `course-04-...md:76` exact `/anything/admin`: 403, `/anything/admin/users` 200
14. `course-04-...md:119` prefix: both 403, `/anything/api/admin` 200
15. `course-05-...md:56` deny-non-get: GET 200, POST/DELETE 403, fortio POST 403
16. `course-06-...md:56` AUDIT: /headers 200
17. `course-06-...md:77` patched to DENY: /headers 403, /get 200
18. `playground/docs/practice.md:58` task 1
19. `playground/docs/practice.md:132` task 2
20. `course-07-wrap-up.md:138` `astrona list` after destroy

Lab 01 (`ats-015-lab-020-02`):

21. `labs/lab-01/solution.md:125` policy table + three codes. Step 1's output (`POST /notify: 200`, `GET  /admin:  403`) was reused from the old step-by-step guide (same command, same app); confirm it.

Lab 02 (`ats-015-lab-020-02-02`, new):

22. `labs/lab-02/solution.md:17` starting state: only probe-allow-fleet, GET 200, POST 200
23. `labs/lab-02/solution.md:50` apply probe-read-only
24. `labs/lab-02/solution.md:68` shuttle GET 200, POST/DELETE/PATCH 403; fortio GET 200, POST 403
25. `labs/lab-02/solution.md:78` probe log line with matched_policy probe-read-only

## Labs

| Lab | metadata.name | New? | App | After part |
| --- | --- | --- | --- | --- |
| `labs/lab-01` Close A Path With DENY | `ats-015-lab-020-02` | converted (kept name and app) | `deny-demo`: notification-service, booking-service, tester; istioctl demo profile | course-04 |
| `labs/lab-02` Make The Probe Read-Only | `ats-015-lab-020-02-02` | **new** | Starfleet subset: probe, shuttle, fortio, STRICT, seeded ALLOW `probe-allow-fleet`; Helm install | course-05 |

Lab 01 changes: `docs/`, `teardown/`, `manifests/`, `validate.sh`, `bootstrap/setup.sh`, `solution/*.yaml` removed; new `question.md`, `solution.md`, `bootstrap/01-install-istio.sh` (istioctl demo, as before), `bootstrap/02-seed-workloads.sh`, `bootstrap/manifests/` (lab-start + peerauthentication-strict), `solution/apply.sh`, `validation/validate-completed.sh`. The grader no longer needs host `python3`+PyYAML (jsonpath instead), folds in the old `resourceExists` check, and retries each traffic check for up to 90 s (connection draining).

Both labs: `astrona validate` reports only the expected `unknown field "solution"/"question" in metadata.docs`. Run `astrona test` on both.

## astrona.yaml entries for this module (replace lines 166-183 of the module-020 block)

```yaml
      - type: reading
        title: "DENY Policies And Evaluation Order"
        path: sections/section-020/module-02/course.md
      - type: reading
        title: "The Guard Checks The Banned List First"
        path: sections/section-020/module-02/course-01-the-guard-checks-the-banned-list-first.md
      - type: reading
        title: "A Guest List Cannot Overrule The Ban"
        path: sections/section-020/module-02/course-02-a-guest-list-cannot-overrule-the-ban.md
      - type: reading
        title: "Lock Everything With One Empty Rule"
        path: sections/section-020/module-02/course-03-lock-everything-with-one-empty-rule.md
      - type: reading
        title: "Close The Whole Path"
        path: sections/section-020/module-02/course-04-close-the-whole-path.md
      - type: reading
        title: Question
        path: sections/section-020/module-02/labs/lab-01/question.md
      - type: lab
        title: "Close A Path With DENY Lab"
        path: sections/section-020/module-02/labs/lab-01
        difficulty: beginner
        estimated_duration: 15m
        topic: authorization
        task_kind: build
        tags: [authorizationpolicy, deny-policy, paths, evaluation-order, rbac-403]
        learning_goals:
          - Ban a path and everything beneath it with a DENY policy that uses a prefix match
          - Prove that an ALLOW policy for the same path cannot reopen it, because DENY is checked first
          - Keep a service's normal call working next to the ban
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Explicit deny"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-deny/
      - type: reading
        title: "Say It Out Loud: Negative Fields"
        path: sections/section-020/module-02/course-05-say-it-out-loud-negative-fields.md
      - type: reading
        title: Question
        path: sections/section-020/module-02/labs/lab-02/question.md
      - type: lab
        title: "Make The Probe Read-Only Lab"
        path: sections/section-020/module-02/labs/lab-02
        difficulty: beginner
        estimated_duration: 15m
        topic: authorization
        task_kind: build
        tags: [authorizationpolicy, deny-policy, methods, evaluation-order, rbac-403, access-log]
        learning_goals:
          - Write a DENY policy with notMethods that refuses every method except GET for every caller
          - Prove with live requests from two callers that an open ALLOW policy cannot let writes through
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Authorization for HTTP traffic"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-http/
      - type: reading
        title: "AUDIT, And Choosing ALLOW Or DENY"
        path: sections/section-020/module-02/course-06-audit-and-choosing-allow-or-deny.md
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-020/module-02/course-07-wrap-up.md
```

## Section README (`sections/section-020/README.md`, lines 46-58)

Replace the module 2 block with something like:

```markdown
*   **Module Reader:** **[Module 2: DENY Policies And Evaluation Order](./module-02/course.md)**
    1. [The Guard Checks The Banned List First](./module-02/course-01-the-guard-checks-the-banned-list-first.md)
    2. [A Guest List Cannot Overrule The Ban](./module-02/course-02-a-guest-list-cannot-overrule-the-ban.md)
    3. [Lock Everything With One Empty Rule](./module-02/course-03-lock-everything-with-one-empty-rule.md)
    4. [Close The Whole Path](./module-02/course-04-close-the-whole-path.md)
    5. [Say It Out Loud: Negative Fields](./module-02/course-05-say-it-out-loud-negative-fields.md)
    6. [AUDIT, And Choosing ALLOW Or DENY](./module-02/course-06-audit-and-choosing-allow-or-deny.md)
    7. [Wrap-Up: Mission Debrief](./module-02/course-07-wrap-up.md)
*   **Hands-on Playground:** `sections/section-020/module-02/playground`: the Starfleet on the planet `starfleet` under `STRICT` mTLS, with the shuttle and fortio as two callers with different ID badges, and the echo probe as the ship you protect.
*   **Graded labs:** [Close A Path With DENY](./module-02/labs/lab-01/) (its own small app in `deny-demo`) and [Make The Probe Read-Only](./module-02/labs/lab-02/) (the Starfleet). Read each `question.md`, then `astrona run` / `astrona submit` as in the lab README.
```

The old README line points at `labs/lab-01/docs/exam-question.md`, which no longer exists.

## new-data files used

Only this module (delete after verification):

- `new-data/securing-workloads/examples/02-authorization/03-authorizationpolicy-httpbin-deny-status.yaml`
- `new-data/securing-workloads/examples/02-authorization/cases/c2-authorizationpolicy-deny-non-get.yaml`
- `new-data/securing-workloads/examples/02-authorization/cases/c4-authorizationpolicy-deny-all.yaml`

Shared with 020-01 (delete only when 020-01 is also done):

- `.../02-authorization/02-authorizationpolicy-httpbin-allow-curl-get.yaml` (renamed copy as examples/02)
- `.../02-authorization/cases/c3-authorizationpolicy-allow-all.yaml` (renamed copy as cases/c2)
- `.../02-authorization/README.md` (DENY sections, mermaid order, TCP-port warning, 45 s wait note), `.../02-authorization/PRACTICE.md` (no DENY content to take)
- `new-data/securing-workloads/README.md` section 4 (spec table, order) and section 5 (403 row) - also used by 010-03 and 030-01.

## Open doubts to check on the cluster

1. **TCP-port warning on apply** (course-01): new-data says applying the `/status/*` DENY prints a "will deny all traffic to TCP ports" warning. Capture it exactly or remove that paragraph.
2. **notification-service answers 200 on every path** (its nginx `location /` returns 200). The old pages claimed `/admin` returns `404`. lab-01 `question.md`/`solution.md` now say `200`; confirm by removing the DENY and calling `/admin` once.
3. **jsonpath array format** in lab-01 grader check 3 and lab-02 notMethods check: they grep for `"/admin` / `"GET"` assuming kubectl prints lists as JSON (`["/admin*"]`). Confirm.
4. **AUDIT without a provider** (course-06): confirm istiod accepts `action: AUDIT` with no audit provider, the reply is unchanged, and nothing special shows in the access log. Adjust the paragraph if the log shows something.
5. **`*` in the middle of a path** (course-04 pitfall): the text now only says it is not a wildcard there. Check Istio 1.30 behaviour (exact literal vs `{*}` templates) if you want a sharper sentence.
6. **`notPrincipals: ["*"]` refuses callers without identity** (course-05): stated as a fact, not demonstrated (STRICT blocks the drifter first). Optional: verify on a PERMISSIVE namespace.
7. **go-httpbin** answers `PATCH /anything`, `DELETE /delete`, `/anything/admin/users` with 200 (lab-02 grader and course-04 depend on it).
8. **`fortio curl -quiet ... | head -1`** prints `HTTP/1.1 <code> <text>`; the lab-02 grader takes field 2.
9. **45 s connection-drain wait**: kept from new-data. Both graders retry up to 90 s; confirm `astrona test` passes in that window.
10. **`probe_guard_log`** uses `kubectl logs -l app=probe` (two pods, 10 lines each by default with a selector); `tail -1` may not be the newest line overall. Adjust if the outputs look wrong.
