# new-data coverage check (temporary)

Checked on 2026-10-09 against `new-data/securing-workloads/` as it is on disk
on branch `evaluate-docs`. Every item below is in the course exactly once per
module (a module may restate a fact from another module, because each module
stands on its own). Ignored on purpose: new-data `bootstrap/` and
`config.yaml` files (the playgrounds replace them), "Further reading" links
(no outside links on pages), and lab-runner notes (`astrona run -c .`,
`ISTIO_VERSION=...`, "Lab not working?"), which the playground overviews
replace.

Status: **covered** = already in the course; **added** = filled in by this
check; **trimmed** = a second explanation in the same module was cut to one
sentence.

Files already removed from new-data before this check (merged earlier, see
`.astrona/merge-plan.md`): all of `examples/01-mtls/`, and
`examples/02-authorization/` 01, 02, 04, c1, c3 and `PRACTICE.md`. Their
course homes are listed at the end for completeness.

## Topic README (`new-data/securing-workloads/README.md`)

| Item | Course location (file and heading) | Status |
| --- | --- | --- |
| Intro: "may this request come in, is the traffic protected" | `sections/intro/course-01-welcome.md`, "What you can do at the end" | covered |
| 1. Building blocks table (5 objects, TLS modes) | `sections/intro/course-01-welcome.md`, "The words this course uses" (new table) | added |
| TLS / mTLS / JWT definitions | `sections/intro/course-01-welcome.md`, "What you can do at the end" | covered |
| Two kinds of identity (workload `spiffe://...` in `principals`/`namespaces`; end user `<iss>/<sub>` and `request.auth.claims`) | `section-030/module-01/course-01-two-identities-on-one-signal.md`, "The workload and the end user" > "Two kinds of identity" | covered |
| 2. Where the checks happen (PeerAuthentication > RequestAuthentication > AuthorizationPolicy > app, on the receiving proxy) | `section-020/module-01/course-01-the-guard-at-the-airlock.md`, "Four checks, in a fixed order" | covered |
| "At the edge, the gateway does the checks instead" | same file and heading (one sentence) | added |
| Calling side set by `DestinationRule` `tls`, auto mTLS | `section-010/module-02/course-06-client-and-server-must-agree.md`, "Two sides, two objects" > "Auto mTLS fills the gap" | covered |
| 3. Order to apply: "security mistakes lock people out" | `section-010/module-03/course-02-write-down-where-you-stand.md`, "The safe order" | covered |
| 3.1 PERMISSIVE first, check callers (`connection_security_policy`), then STRICT | `section-010/module-03/course-02-write-down-where-you-stand.md`, "The safe order" > "Adding STRICT"; measuring in `course-01-count-the-plain-signals.md` | covered (Kiali left out: not in the playground) |
| 3.2 RequestAuthentication before the token policy | `section-030/module-01/course-03-require-a-token.md`, "Apply things in the right order" | covered |
| 3.3 ALLOW rules before allow-nothing; identity rules need mTLS | `section-020/module-01/course-02-close-the-airlock.md`, "Why keep the allow-nothing policy afterwards"; `course-04-name-the-caller.md`, "Why the identity needs mTLS" | covered |
| Remove in reverse order (all three) | 010-03 `course-02-...`, "Removing it again"; 020-01 `course-02-...` (same heading as 3.3); 030-01 `course-03-...`, "Apply things in the right order" | covered |
| 4. PeerAuthentication: port > workload > namespace > mesh | `section-010/module-02/course-03-three-scopes-narrowest-wins.md`, "Narrowest wins" > "The order" | covered |
| 4. AuthorizationPolicy order CUSTOM > DENY > ALLOW, "no ALLOW policy = allowed" | `section-020/module-02/course-01-the-guard-checks-the-banned-list-first.md`, "Three actions, one fixed order" | covered |
| Spec table (`spec: {}`, `rules: [{}]`, DENY + `rules: [{}]`) | `section-020/module-02/course-03-lock-everything-with-one-empty-rule.md`, "Three look-alike specs" > "The table" | covered |
| 5. Errors: reset / curl exit 56 (STRICT, no sidecar) | `section-010/module-02/course-02-require-the-handshake.md`, "No status code: 000 and exit 56" | covered |
| 5. Errors: exit 56 for MUTUAL gateway without client certificate | `section-040/module-02/course-02-make-the-gate-ask-for-a-badge.md`, "See it in your playground" (exit code table) | covered |
| 5. Errors: 503 `UC` (client `DISABLE` vs server STRICT) | `section-010/module-02/course-06-client-and-server-must-agree.md`, "Read the failure" | covered |
| 5. Errors: 401 `Jwt ...` | `section-030/module-01/course-02-check-the-token.md`, "Three outcomes of the check" | covered |
| 5. Errors: 403 `RBAC: access denied`, `matched_policy[...]` | `section-020/module-01/course-06-find-out-why-the-guard-says-no.md`, "Read the decision in the access log" | covered |
| 5. Errors: curl exit 60 | `section-040/module-01/course-02-open-the-https-door.md`, "Without trust, no response" | covered |

## `examples/README.md`

| Item | Course location | Status |
| --- | --- | --- |
| Two test clients table (mesh client, plain client in another namespace, full host names) | `section-010/module-02/playground/docs/overview.md` and `section-010/module-02/course-01-two-callers-one-default.md` (`probe.starfleet`) | covered |
| `istioctl x describe pod` | `section-010/module-02/course-04-read-the-mode-off-the-ship.md`, "Ask the pod" | covered |
| Access log `rbac_access_denied_matched_policy` | `section-020/module-01/course-06-find-out-why-the-guard-says-no.md` | covered |
| `istioctl proxy-config secret` on the gateway | `section-040/module-01/course-02-open-the-https-door.md`, "From the gateway's side" | covered |
| `istioctl analyze` | `section-020/module-01/course-06-...`, "Ask istioctl analyze"; `section-040/module-01/course-04-...`, "Ask `istioctl analyze`" | covered |
| Wait after an apply (old connections keep old rules) | `section-020/module-01/course-02-close-the-airlock.md` (tip); 020-02 and 030-01/02 playground overviews | covered |
| Start over (delete all policies) | each playground `docs/overview.md`, reset block | covered |

## `examples/02-authorization` (remaining files)

| Item | Course location | Status |
| --- | --- | --- |
| `03-authorizationpolicy-httpbin-deny-status.yaml` | `section-020/module-02/playground/examples/01-deny-policies/01-authorizationpolicy-probe-deny-status.yaml`; taught in `course-01-the-guard-checks-the-banned-list-first.md`, "Deny one path" | covered |
| `cases/c2-authorizationpolicy-deny-non-get.yaml` | `.../01-deny-policies/cases/c1-authorizationpolicy-deny-non-get.yaml`; `course-05-say-it-out-loud-negative-fields.md`, "Deny everything except reads" | covered |
| `cases/c4-authorizationpolicy-deny-all.yaml` | `.../01-deny-policies/cases/c3-authorizationpolicy-deny-all.yaml`; `course-03-lock-everything-with-one-empty-rule.md`, "Deny everything" | covered |
| README: Learning objectives | `section-020/module-01/course.md` and `section-020/module-02/course.md`, "Learning objectives" | covered |
| README: Before you start (clients table, helpers, wait) | `section-020/module-01/course.md` and `section-020/module-02/course.md`, "Before you start"; playground overviews | covered |
| README: How a request is judged (flow, rules OR, from/to/when AND) | `section-020/module-02/course-01-...`, "Three actions, one fixed order"; `section-020/module-01/course-03-write-a-guest-list-entry.md`, "How the pieces combine" | covered |
| README: Deny everything (`spec: {}`, `matched_policy[none]`) | `section-020/module-01/course-02-close-the-airlock.md`, "The allow-nothing policy" | covered |
| README: Allowing one caller and one method | `section-020/module-01/course-03-write-a-guest-list-entry.md`, "Open one call" | covered |
| README: DENY wins over ALLOW, TCP-ports warning | `section-020/module-02/course-01-...`, "Deny one path"; `course-02-a-guest-list-cannot-overrule-the-ban.md` | covered |
| README: Least privilege for a real app | `section-020/module-01/course-05-least-privilege-for-the-fleet.md` | covered |
| README pitfall: no sidecar caller, use `ipBlocks` or a sidecar | `section-020/module-01/course-04-name-the-caller.md`, "No certificate, no match" | added |
| README Cases 1-4 | 020-01 `course-04-...` "A whole namespace at once"; 020-02 `course-05-...`; 020-01 `course-02-...` "`spec: {}` and `rules: [{}]` are opposites"; 020-02 `course-03-...` | covered |
| README: `not` fields mean "everything except"; lockdown for an incident | 020-01 `course-03-...`, "The three parts of a rule"; 020-02 `course-05-...`; 020-02 `course-03-...`, "Deny everything" | covered |
| Exam cheat sheet (fields, actions, no selector = namespace, path forms, `ports`, `when` headers, principal format, find the service account, 403 body) | `section-020/module-01/course-03-write-a-guest-list-entry.md`, "The three parts of a rule", "Path matching, exactly", "`when`, briefly"; `course-04-name-the-caller.md`, "Find each workload's service account" | covered |

## `examples/03-jwt-authentication`

| Item | Course location | Status |
| --- | --- | --- |
| `01-requestauthentication-httpbin.yaml` | `section-030/module-01/playground/examples/01-require-a-token/01-requestauthentication-probe.yaml`; `course-02-check-the-token.md`, "Turn on the token check" | covered |
| `02-authorizationpolicy-httpbin-require-jwt.yaml` | `.../01-require-a-token/02-authorizationpolicy-probe-require-jwt.yaml`; `course-03-require-a-token.md`, "Add an AuthorizationPolicy to the probe" | covered |
| `03-authorizationpolicy-httpbin-require-group.yaml` | `section-030/module-02/playground/examples/03-jwt-claims/01-authorizationpolicy-probe-require-group.yaml`; `course-02-require-a-claim.md`, "Only group1 may pass" | covered |
| `cases/c1-...token-in-query.yaml` | `.../01-require-a-token/cases/c1-requestauthentication-probe-token-in-query.yaml`; 030-01 `course-04-other-token-places-and-deny.md`, "Read the token from a query parameter" | covered |
| `cases/c2-...deny-without-token.yaml` | `.../cases/c2-authorizationpolicy-probe-deny-without-token.yaml`; 030-01 `course-04-...`, "Write \"token required\" as DENY" | covered |
| `cases/c3-...require-scope3.yaml` | `section-030/module-02/.../cases/c1-authorizationpolicy-require-scope3.yaml`; `course-02-require-a-claim.md`, "A claim no token has" | covered |
| `cases/c4-...public-path.yaml` | `section-030/module-02/.../cases/c2-authorizationpolicy-public-path.yaml`; `course-03-one-rule-per-role.md`, "One public path" | covered |
| README: Learning objectives | `section-030/module-01/course.md`, `section-030/module-02/course.md` | covered |
| README: What is in a JWT (parts, claims, JWKS, decode, signed not encrypted) | `section-030/module-01/course-01-...`, "What is inside a token" | covered |
| README: Two resources, two questions (401 vs 403, no token is not invalid) | 030-01 `course-02-...`, "Three outcomes of the check"; `course-03-...`, "401 and 403 point at different objects" | covered |
| README: Requiring a claim (list contains the value) | 030-02 `course-02-require-a-claim.md`, "How a `when` condition fits" | covered |
| README pitfalls (RequestAuthentication alone, order, `fromParams`, 403 with valid token: decode) | 030-01 `course-02-...` / `course-03-...` / `course-04-...` pitfalls; 030-02 `course-04-debug-a-claim-rule.md` | covered |
| Case 2 "DENY does not switch to allow-list; used at the ingress gateway" | 030-01 `course-04-...`, "The one difference" | covered |
| Cheat sheet: `jwks` inline, `fromHeaders`, `forwardOriginalToken`, `<iss>/<sub>` | 030-01 `course-02-check-the-token.md`, "The fields inside one rule"; `course-03-...` pitfalls | covered |
| Cheat sheet: RequestAuthentication on the gateway (`istio: ingress` in its namespace) | 030-01 `course-02-check-the-token.md`, "Which workloads, and which issuers" | added |
| `PRACTICE.md` (claim `foo: bar`) | `section-030/module-02/playground/docs/practice.md` | covered |

## `examples/04-ingress-https`

| Item | Course location | Status |
| --- | --- | --- |
| `01-gateway-bookinfo-https.yaml` | `section-040/module-01/playground/examples/01-gateway-starfleet-https.yaml`; `course-02-open-the-https-door.md`, "The TLS server" | covered |
| `02-virtualservice-bookinfo.yaml` | `section-040/module-01/playground/examples/02-virtualservice-bridge.yaml`; `course-02-...`, "Link the `VirtualService`" | covered |
| `03-gateway-bookinfo-mutual.yaml` | `section-040/module-02/playground/examples/02-gateway-starfleet-mutual.yaml`; `course-02-make-the-gate-ask-for-a-badge.md`, "Switch the gateway to `MUTUAL`" | covered |
| `cases/c1-make-other-ca-client-cert.sh` | `section-040/module-02/playground/examples/cases/c1-make-other-ca-client-cert.sh`; `course-03-turn-away-strangers-and-prove-it.md`, "A client certificate from another CA" | covered |
| `cases/c2-gateway-secret-wrong-namespace.yaml` | `section-040/module-01/playground/examples/cases/c1-gateway-secret-wrong-namespace.yaml`; `course-04-when-the-handshake-fails.md`, "A Secret in the wrong namespace" | covered |
| Case 3 wrong SNI (even with `-k`) | `section-040/module-01/course-04-...`, "A host the gateway does not serve" | covered |
| README: SNI, Secret in the gateway pod's namespace, subject/issuer check | 040-01 `course-01-give-the-gate-its-certificate.md`, "Where the gateway looks for its certificate"; `course-02-...`, "Why `--resolve` matters", "Prove which certificate answered" | covered |
| README: HTTPS redirect (301, keeps the local port) | 040-01 `course-03-redirect-and-rotate.md`, "Send plain HTTP to HTTPS" | covered |
| README: exit codes 0/7/35/56/60 | 040-01 `course-04-...`, "The codes you will meet"; 040-02 `course-02-...` table | covered |
| README: TLS modes table (SIMPLE / MUTUAL / PASSTHROUGH, secret contents) | 040-02 `course-02-make-the-gate-ask-for-a-badge.md`, "Switch the gateway to `MUTUAL`" | added |
| Cheat sheet: `secret tls` / `secret generic` with `ca.crt`, `proxy-config secret` | 040-01 `course-01-...`, "Create the Secret"; 040-02 `course-02-...`, "One secret, two jobs" | covered |
| `PRACTICE.md` (secret `bookinfo-tls` + redirect) | `section-040/module-01/playground/docs/practice.md` (`starfleet-tls`) | covered |

## `examples/05-egress-tls-origination`

| Item | Course location | Status |
| --- | --- | --- |
| `01-serviceentry-httpbin-org.yaml`, `02-destinationrule-httpbin-org-tls.yaml` | `section-040/module-04/playground/examples/01-egress-tls-origination/`; `course-02-chart-the-planet-and-seal-the-signal.md` | covered |
| `cases/c1-destinationrule-wrong-san.yaml` | same folder; `course-03-check-the-planets-id-card.md`, "See a wrong name fail" | covered |
| `cases/c2-serviceentry-without-target-port.yaml` | same folder; `course-04-a-seal-on-the-wrong-channel.md`, "Forget the `targetPort`" | covered |
| `cases/c3-virtualservice-httpbin-org-timeout.yaml` | same folder; `course-05-use-what-you-won.md`, "A timeout on an outside HTTPS service" | covered |
| README: Learning objectives, Who does the TLS, `tls` modes, `"url"` field | `section-040/module-04/course.md`; `course-01-who-seals-the-signal.md` | covered |
| README: Half done (400), the sidecar starts TLS, app `https://` still works | `course-02-...`, "Half done: add the ServiceEntry", "Add the TLS settings" | covered |
| README pitfalls and symptom table (400, `WRONG_VERSION_NUMBER`, `CERTIFICATE_VERIFY_FAILED`, `sni` not caught, `caCertificates`) | `course-03-...`; `course-04-...`, "Three failures, three causes" | covered |
| Cheat sheet: MUTUAL to an outside service | `course-05-...`, "Mutual TLS to an outside service" | covered |
| `PRACTICE.md` (www.google.com) | `section-040/module-04/playground/docs/practice.md` | covered |

## Removed from new-data earlier (course homes)

| Item | Course location | Status |
| --- | --- | --- |
| `01-mtls` 01, 02, 04, c2 | `section-010/module-02/playground/examples/01-mtls/`; `course-02-require-the-handshake.md`, `course-03-three-scopes-narrowest-wins.md` | covered |
| `01-mtls` c1 (`portLevelMtls`) | `.../01-mtls/cases/c1-peerauthentication-probe-port-level.yaml`; `course-05-an-exception-for-one-port.md` | covered |
| `01-mtls` 03, c3, c4 | `.../01-mtls/`; `course-06-client-and-server-must-agree.md` | covered |
| `01-mtls/PRACTICE.md` | `section-010/module-02/playground/docs/practice.md` | covered |
| `02-authorization` 01, 02, 04, c1, c3 | `section-020/module-01/playground/examples/01-allow-policies/`; parts 02 to 05 | covered |
| `02-authorization/PRACTICE.md` | `section-020/module-01/playground/docs/practice.md`, `section-020/module-02/playground/docs/practice.md` | covered |

## Duplicates

| Where | What | Action |
| --- | --- | --- |
| `section-020/module-01/course-05-least-privilege-for-the-fleet.md`, "Why the narrow policies work together" | apply/remove order, explained in full in `course-02-close-the-airlock.md` | trimmed to one sentence |
| `section-010/module-03/course-04-switch-to-strict-for-good.md`, "The rollback plan" | reverse order of the migration, explained in `course-02-...` | already one sentence, kept |
| `section-010/module-03/course-01-measuring-with-telemetry.md`, `course-02-exceptions-and-meshing.md`, `course-03-enforcing-and-rolling-back.md`, `course-03-keep-one-port-open.md` | old drafts of the 010-03 parts, not listed in `astrona.yaml`; their content is in the listed parts | **maintainer: delete these four files** (not deleted here) |

## Needs a cluster run

Nothing. Every missing item was a fact or a table that needed no new command
output.
