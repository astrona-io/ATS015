# Hand-over: 060-01 Authorization In Ambient Mode, L4 And L7

Drafted without a cluster. Delete this file after verification.

## Playground

- Name: `ats-015-playground-060-01` (`astrona run -c sections/section-060/module-01/playground`).
- `bootstrap/install-istio.sh`: Gateway API CRDs v1.3.0, then Helm (Istio 1.30.5):
  `istio-base`, `istiod --set profile=ambient`, `istio-cni --set profile=ambient`
  (chart `cni`), `ztunnel`. Waits for GatewayClass `istio-waypoint`.
  Pins kube context `kind-astro-ats-015-playground-060-01` (ATS014 playground style).
- `bootstrap/deploy.sh`: `namespace.yaml` (starfleet, label
  `istio.io/dataplane-mode=ambient`, no injection label), `access-logs.yaml`
  (mesh Telemetry; only the waypoint writes Envoy logs), `starfleet.yaml`,
  `shuttle.yaml`, `probe.yaml` (copied from ATS014 010-01; comments in
  shuttle/access-logs adapted to ambient). No fortio/outpost: not needed.
- `examples/01-l4-policy/` and `examples/02-waypoint-l7/` hold the YAML the parts
  use, plus cases. `docs/overview.md`, `docs/practice.md` (2 tasks, written new:
  there is no new-data for this module), `README.md`.
- Old `bootstrap/prepare.sh` and `manifests/lab-start.yaml` deleted.

## Parts (old 4 parts rewritten, renamed, one wrap-up added)

1. `course-01-the-ambient-dataplane.md` (same file name)
2. `course-02-what-ztunnel-can-enforce.md` (same file name) - ends with mission lab-02
3. `course-03-a-rule-with-nowhere-to-run.md` (new; replaces `course-03-waypoints-and-l7-policy.md`)
4. `course-04-deploy-a-waypoint.md` (new; replaces part of old part 3) - ends with mission lab-01
5. `course-05-ask-who-holds-the-rule.md` (new; replaces `course-04-tooling-and-carrying-across.md`)
6. `course-06-wrap-up.md` (new)

Hands-on runs in one playground session in this order (state carries over:
`cargo-l4` from part 2, `probe-l7` from part 3, waypoint + `probe` label from part 4
are needed in part 5). Part 3 changes `cargo-l4` and restores it.

## OUTPUT PENDING locations, in run order

Run parts 1 to 5 in one playground, then practice.md (from a clean planet, see
overview.md "Start over"), then the labs.

- `course-01-the-ambient-dataplane.md`:89:starfleet Active ... istio.io/dataplane-mode=ambient,kubernetes.io/metadata.name=starfleet
- `course-01-the-ambient-dataplane.md`:101:bridge-v1, cargo-v1, navcom-v1, probe-v1/v2, scout-v1/v2/v3, shuttle, all READY 1/1 Running
- `course-01-the-ambient-dataplane.md`:113:header NAMESPACE POD NAME ADDRESS NODE WAYPOINT PROTOCOL, then one line per starfleet pod with WAYPOINT None and PROTOCOL HBONE
- `course-01-the-ambient-dataplane.md`:125:No resources found in starfleet namespace.
- `course-02-what-ztunnel-can-enforce.md`:41:authorizationpolicy.security.istio.io/cargo-l4 created
- `course-02-what-ztunnel-can-enforce.md`:53:000, plus "command terminated with exit code 56" (connection reset), not 403
- `course-02-what-ztunnel-can-enforce.md`:65:200 (the bridge reached cargo with its own identity)
- `course-02-what-ztunnel-can-enforce.md`:124:an "error access connection complete" line with src.identity spiffe://cluster.local/ns/starfleet/sa/shuttle, dst.workload cargo-v1-..., and error "connection closed due to policy rejection: allow policies exist, but none allowed"
- `course-03-a-rule-with-nowhere-to-run.md`:43:authorizationpolicy.security.istio.io/probe-l7 created
- `course-03-a-rule-with-nowhere-to-run.md`:56:GET: 200 and POST: 200 (the POST should be refused, but nothing enforces the rule)
- `course-03-a-rule-with-nowhere-to-run.md`:69:both cargo-l4 and probe-l7 listed; status condition type WaypointAccepted, status False, with a message saying the probe Service is not bound to a waypoint (drop this command if Istio 1.30.5 writes no status)
- `course-03-a-rule-with-nowhere-to-run.md`:125:authorizationpolicy.security.istio.io/cargo-l4 configured
- `course-03-a-rule-with-nowhere-to-run.md`:137:no longer 200 (the bridge cannot reach cargo; expect 500 or 503 from the bridge)
- `course-03-a-rule-with-nowhere-to-run.md`:156:authorizationpolicy.security.istio.io/cargo-l4 configured
- `course-04-deploy-a-waypoint.md`:30:waypoint starfleet/waypoint applied
- `course-04-deploy-a-waypoint.md`:39:gateway.gateway.networking.k8s.io/waypoint condition met; then NAME waypoint, CLASS istio-waypoint, an ADDRESS, PROGRAMMED True
- `course-04-deploy-a-waypoint.md`:47:POST: 200 (the waypoint exists, but no signal goes through it yet)
- `course-04-deploy-a-waypoint.md`:59:service/probe labeled
- `course-04-deploy-a-waypoint.md`:67:header NAMESPACE SERVICE NAME SERVICE VIP WAYPOINT ENDPOINTS; probe shows WAYPOINT waypoint, the other starfleet services show None
- `course-04-deploy-a-waypoint.md`:84:GET: 200 and POST: 403
- `course-04-deploy-a-waypoint.md`:96:two access log lines: "GET /anything" 200 and "POST /anything" 403 with rbac_access_denied_matched_policy[none]; trim the lines
- `course-05-ask-who-holds-the-rule.md`:32:ztunnel-config policy lists only starfleet cargo-l4 (action Allow, scope WorkloadSelector); kubectl lists cargo-l4 and probe-l7
- `course-05-ask-who-holds-the-rule.md`:44:ns[starfleet]-policy[probe-l7]
- `course-06-wrap-up.md`:132:No astrona labs running.
- `playground/docs/practice.md`:56:000 and "command terminated with exit code 56"
- `playground/docs/practice.md`:65:200
- `playground/docs/practice.md`:90:waypoint starfleet/waypoint applied; condition met; service/probe labeled
- `playground/docs/practice.md`:129:GET: 200 and POST: 403
- `labs/lab-02/solution.md`:16:header line, then one line per starfleet pod with WAYPOINT None and PROTOCOL HBONE; then "No resources found in starfleet namespace."
- `labs/lab-02/solution.md`:26:bridge-v1 starfleet-bridge, cargo-v1 starfleet-cargo, navcom-v1 starfleet-navcom, scout-v1/v2/v3 starfleet-scout, shuttle shuttle
- `labs/lab-02/solution.md`:65:000 with "command terminated with exit code 56", then 200
- `labs/lab-02/solution.md`:108:000 with "command terminated with exit code 56"; then star lines for v2/v3 answers, nothing for v1 answers, never "Ratings service is currently unavailable"
- `labs/lab-02/solution.md`:121:ztunnel-config policy lists starfleet cargo-l4 and starfleet navcom-l4 (Allow, WorkloadSelector); log lines with src.identity .../sa/shuttle and "connection closed due to policy rejection"
- `labs/lab-01/solution.md`:16:header line, then notification-service-v1, other-client and tester with WAYPOINT None and PROTOCOL HBONE; then "No resources found in ambient-authz namespace."
- `labs/lab-01/solution.md`:28:waypoint ambient-authz/waypoint applied, and a line saying namespace ambient-authz is labeled with istio.io/use-waypoint: waypoint
- `labs/lab-01/solution.md`:37:condition met; NAME waypoint, CLASS istio-waypoint, an ADDRESS, PROGRAMMED True
- `labs/lab-01/solution.md`:83:authorizationpolicy.security.istio.io/notification-l7 created
- `labs/lab-01/solution.md`:93:tester POST: 200, tester GET: 403, other-client POST: 403
- `labs/lab-01/solution.md`:114:ztunnel-config policy lists no policy for ambient-authz (header only); the waypoint log shows the last three requests, with 403 and rbac_access_denied_matched_policy[none] on the refused ones

## Labs

| Lab | metadata.name | New? | App | After part |
| --- | --- | --- | --- | --- |
| `labs/lab-02` Allow Only Known Ships At L4 | `ats-015-lab-060-01-02` | **new** | Starfleet (ambient) | 2 |
| `labs/lab-01` Enforce L4 And L7 Policy In Ambient Mode | `ats-015-lab-060-01` (kept) | converted | own app: `ambient-authz`, `notification-service`, `tester`/`other-client` | 4 |

lab-01 conversion: `docs/`, `teardown/`, `manifests/`, `bootstrap/setup.sh`, old
`solution/*.yaml` deleted; `validate.sh` -> `validation/validate-completed.sh`
(resourceExists checks folded in: waypoint Gateway with class `istio-waypoint` and
Programmed=True, AuthorizationPolicy with `targetRefs`); install moved from
`istioctl install --set profile=ambient` to Helm ambient; namespace label moved into
`bootstrap/manifests/namespace.yaml`; access logs added so the waypoint log step in
solution.md works. `solution/apply.sh` applies the waypoint Gateway YAML (no istioctl in
CI), labels the namespace, applies `notification-l7`.

Both labs: `astrona validate` only reports the expected `metadata.docs.question/solution`
"unknown field" errors (CLAUDE.md says keep them). `astrona test` not run (no cluster).

## astrona.yaml entries for module-060 (replace lines for this module only)

Topic and tags: CLAUDE.md's topic and tag lists are the ATS014 traffic lists and have no
security terms. I used `topic: foundations` and only listed tags that exist
(`virtualservice`-style tags do not fit). Suggested new tags to add to the list first:
`authorizationpolicy`, `ambient`, `waypoint`, `ztunnel`, `principals`, `targetrefs`.
The maintainer should decide; adjust before writing.

```yaml
      - type: reading
        title: "Authorization In Ambient Mode, L4 And L7"
        path: sections/section-060/module-01/course.md
      - type: reading
        title: "The Ambient Dataplane"
        path: sections/section-060/module-01/course-01-the-ambient-dataplane.md
      - type: reading
        title: "What ztunnel Can Enforce"
        path: sections/section-060/module-01/course-02-what-ztunnel-can-enforce.md
      - type: reading
        title: Question
        path: sections/section-060/module-01/labs/lab-02/question.md
      - type: lab
        title: "Allow Only Known Ships At L4 Lab"
        path: sections/section-060/module-01/labs/lab-02
        difficulty: beginner
        estimated_duration: 15m
        topic: foundations
        task_kind: build
        tags: [authorizationpolicy, ambient, ztunnel, principals, sidecar-injection, proxy-config]
        learning_goals:
          - Write identity-only ALLOW policies that ztunnel enforces with no waypoint
          - Recognise an L4 refusal as a closed connection instead of a 403
          - Keep the allowed callers working while every other ship is refused
        resources:
          - name: "Ambient L4 authorization policy"
            url: https://istio.io/latest/docs/ambient/usage/l4-policy/
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
      - type: reading
        title: "A Rule With Nowhere To Run"
        path: sections/section-060/module-01/course-03-a-rule-with-nowhere-to-run.md
      - type: reading
        title: "Deploy A Waypoint"
        path: sections/section-060/module-01/course-04-deploy-a-waypoint.md
      - type: reading
        title: Question
        path: sections/section-060/module-01/labs/lab-01/question.md
      - type: lab
        title: "Enforce L4 And L7 Policy In Ambient Mode Lab"
        path: sections/section-060/module-01/labs/lab-01
        difficulty: intermediate
        estimated_duration: 20m
        topic: foundations
        task_kind: build
        tags: [authorizationpolicy, ambient, waypoint, targetrefs, gateway-api, access-log]
        learning_goals:
          - Deploy a waypoint and send a service's traffic through it with istio.io/use-waypoint
          - Attach one L7 policy with targetRefs that enforces both identity and method
          - Tell a waypoint refusal (403) from a ztunnel refusal (closed connection)
        resources:
          - name: "Use waypoint proxies"
            url: https://istio.io/latest/docs/ambient/usage/waypoint/
          - name: "Ambient L7 features"
            url: https://istio.io/latest/docs/ambient/usage/l7-features/
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
      - type: reading
        title: "Ask Who Holds The Rule"
        path: sections/section-060/module-01/course-05-ask-who-holds-the-rule.md
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-060/module-01/course-06-wrap-up.md
```

Tag note: `sidecar-injection` and `proxy-config` exist in the list but are weak fits;
`gateway-api` and `access-log` exist. Replace the not-yet-listed tags
(`authorizationpolicy`, `ambient`, `ztunnel`, `principals`, `waypoint`, `targetrefs`)
once they are added to CLAUDE.md, or pick existing ones. Check every resource URL loads.

## Section README lines to update (`sections/section-060/README.md`)

- "Deep-dive parts, in reading order": replace the 4 links with the 6 new files
  (titles as in the YAML above).
- Hands-on Playground line: now the Starfleet on namespace `starfleet` (ambient,
  Helm install with istiod/istio-cni/ztunnel), shuttle + probe; not `ambient-authz`.
- Graded labs: add lab-02 "Allow Only Known Ships At L4" (Starfleet, new); lab-01 link
  should point at `./module-01/labs/lab-01/question.md` (not `docs/exam-question.md`,
  which is deleted); submit commands use the full lab path, not `-c .`.
- Remove "from section 020/010/030" references and the "there are no sidecars ...
  earlier sections" sentence (cross-section references).

## new-data files used

None (no new-data maps to 060-01).

## Open doubts to check on the cluster

1. Helm ambient install on kind: `istiod` and `cni` with `--set profile=ambient`, `ztunnel`
   with no profile. Does kind need any `global.platform` value? Does Gateway API v1.3.0
   suit 1.30.5 (ATS014 060-03 uses it)?
2. `istioctl ztunnel-config workload` / `service` / `policy` column names and output
   format; I used `| grep -E "NAMESPACE|starfleet"` instead of a namespace flag. If a
   filter flag (`--workload-namespace`?) exists, either form is fine.
3. ztunnel denial log text (`connection closed due to policy rejection: allow policies
   exist, but none allowed`) and whether `kubectl logs ds/ztunnel | grep -i policy` finds it.
4. **Fail-safe claim (part 3, lab-02 hints, wrap-up Q5):** a `selector` ALLOW policy with
   `methods` and no waypoint makes ztunnel refuse every caller (the bridge loses cargo).
   The old pages claimed such a rule is "silently ignored". Verify; if ztunnel ignores it
   instead, rewrite part 3 "The same rule with a selector", the table, the pitfall and
   wrap-up Q5, and lab-02's validator message.
5. Status on a `targetRefs` policy with no waypoint: condition `WaypointAccepted` False?
   If Istio 1.30.5 writes no status, drop the second command in part 3 "Ask the policy itself".
6. Bridge product API: `/api/v1/products/0` returns 200 when cargo answers and a non-200
   (500?) when cargo refuses; `/api/v1/products/0/reviews` returns 200 via scout (practice).
7. Scout JSON strings used by lab-02's grader: `"stars"` and
   `Ratings service is currently unavailable`.
8. curl exit code on an L4 refusal: 56 (reset) assumed; could be 52 or 7. The `000` code is
   what matters.
9. `istioctl waypoint apply -n starfleet` output text; `--enroll-namespace` output text
   (lab-01); `istioctl waypoint delete --all -n starfleet` (overview "Start over").
10. Waypoint access-log line shows `rbac_access_denied_matched_policy[none]` for the POST;
    the waypoint Deployment is named `waypoint`.
11. `istioctl proxy-config listener deploy/waypoint ... | grep -o 'ns\[starfleet\]-policy\[...\]'`
    finds the policy name in the waypoint RBAC config (part 5). If not, replace with
    another check (for example the access log).
12. Behind a namespace-wide waypoint, ztunnel at the destination sees the waypoint identity,
    so a pod-level allow-only-bridge rule breaks cargo (part 4 prose, wrap-up Q7, lab-01
    question item 4). The old lab guide reported `503` for this; not re-run.
13. lab-01 grader expects other-client POST = 403 (old lab behaviour, kept).
14. lab-02: `astrona test` must pass; grader waits up to 60 s for the shuttle -> cargo
    refusal before reading behaviour.
15. New analogies not in the glossary (consider adding): ztunnel = the relay station on
    each space station (node); HBONE = sealed tunnel between relay stations; waypoint =
    checkpoint ship in front of a beacon; istio-cni = docking crew that reroutes the
    antenna; L4/L7 = outside of the signal capsule / message inside.
