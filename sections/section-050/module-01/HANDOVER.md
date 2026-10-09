# HANDOVER: 050-01 Authorize By Source IP At The Ingress Gateway

Drafted without a cluster. The verify agent runs everything, replaces each
`<!-- OUTPUT PENDING: ... -->` with real output, fixes facts, and deletes this file.

## Playground

`ats-015-playground-050-01` (`sections/section-050/module-01/playground`)

- Helm, Istio 1.30.5: `istio-base`, `istiod` (no extra values), `gateway` chart as
  release `istio-ingress` in namespace `istio-ingress` (`service.type=ClusterIP`,
  pod label `istio=ingress`).
- `deploy.sh`: namespace `starfleet` (injection), mesh-wide access logs
  (Telemetry), Starfleet, shuttle, probe v1/v2, and
  `bootstrap/manifests/gateway-starfleet.yaml` (Gateway `starfleet-gateway`
  port 80 host `starfleet.example.com`; VirtualService `starfleet`:
  `/headers` -> probe:8000, everything else -> bridge:9080).
- `numTrustedProxies` is deliberately NOT set (part 3 sets it with
  `helm upgrade istiod --reuse-values -f values-istiod-topology.yaml`).
- portForwards: `127.0.0.1:8080 -> svc/istio-ingress:80`,
  `127.0.0.1:8443 -> svc/istio-ingress:443`.
- Old `bootstrap/prepare.sh`, `manifests/lab-start.yaml`, `manifests/gateway.yaml` removed (git rm).
- `astrona validate -c playground`: valid.

Reading run order matters: parts 1-2 run with no topology setting; part 3
sets `numTrustedProxies: 1` and it stays for parts 4-5 and practice.md.
Paste the helpers (`gate_status`, `gate_log`) from `course.md` first.

## OUTPUT PENDING locations, in run order

Playground, reading:

1. `course-01-guard-the-arrival-gate.md` - `kubectl get pods -n istio-ingress -L istio`: one pod, ISTIO=ingress
2. `course-01` - `gate_status /productpage` + `/api/v1/products`: 200, 200
3. `course-01` - after policy in `starfleet`: 200
4. `course-01` - after policy in `istio-ingress`: 403, 200, plus 2 gateway log lines (rbac_access_denied_matched_policy...)
5. `course-01` - bridge-v1 istio-proxy log grep + shuttle direct curl: no 403 line in bridge log; 200
6. `course-02-who-opened-the-connection.md` - `gate_status` + `gate_log`: 200, log ending `127.0.0.1:80 127.0.0.1:<port>`
7. `course-02` - ALLOW ipBlocks 10.0.0.0/8: 403, 403
8. `course-02` - ALLOW ipBlocks 127.0.0.1/32: 200, 200 (second with XFF 192.168.5.5)
9. `course-03-trust-the-right-number-of-relays.md` - before: 200, log (XFF field + remote 127.0.0.1), listener grep empty
10. `course-03` - helm upgrade istiod output
11. `course-03` - rollout restart + status
12. `course-03` - listener grep: `"xffNumTrustedHops": 1`
13. `course-03` - after: 200, log remote now 10.1.2.3
14. `course-03` - XFF "192.168.5.5, 10.1.2.3": 200, remote 10.1.2.3
15. `course-04-block-a-client-range.md` - listener grep: 1
16. `course-04` - DENY remoteIpBlocks: 200, 403, 200 (no header)
17. `course-04` - `gate_log 2`: 403 line with policy + remote 192.168.5.5; 200 line remote 127.0.0.1
18. `course-04` - forged entries: "10.1.2.3, 192.168.5.5" 403; "192.168.5.5, 10.1.2.3" 200
19. `course-05-one-path-one-network.md` - office-only: 200, 403, 200
20. `course-05` - `kubectl get authorizationpolicy -A` + istio configmap mesh (shows defaultConfig.gatewayTopology)
21. `course-05` - `gate_log 3`: three lines with remotes
22. `course-06-wrap-up.md` - final `astrona list`: "No astrona labs running."

Playground, `docs/practice.md` (run after part 3 or set topology first):

23. listener grep (top)
24. helm upgrade + restart (top)
25. Task 1: 403, 200
26. Task 2: 200, 403, 200
27. Task 3: openssl + secret created
28. Task 3: HTTP 403, HTTPS 403, HTTPS 200 (curl --resolve ... :8443)

Lab-01 `solution.md` (own app, istioctl demo install):

29. step 1: before 200 + log line, remote 127.0.0.1
30. step 2: listener grep on istio-ingressgateway: 1
31. step 3: `kubectl -n istio-system get pods -L istio | grep gateway`
    (step 4 output `xff 10.1.2.3: 200 / xff 192.168.5.5: 403` reused from the old verified guide; only `localhost` became `127.0.0.1`)

Lab-02 `solution.md` (Starfleet, Helm):

32. step 1: pods -L istio, 200, 200
33. step 2: listener grep: 1
34. step 4: 200, 403, 403, 200, 403
35. step 4: 403 log lines with policy api-office-only

## Labs

| Lab | metadata.name | New? | App |
| --- | --- | --- | --- |
| lab-01 Block A Client Range At The Gateway | `ats-015-lab-050-01` (kept) | converted | own app (`gwauthz-demo`, `booking.ica.local`, istioctl demo, gateway in istio-system, numTrustedProxies via pod annotation patch) |
| lab-02 Open One Path To One Network | `ats-015-lab-050-01-02` | NEW | Starfleet, Helm, istiod value `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies=1` |

Both: `astrona validate` only complains about `metadata.docs.question/solution`
(expected per CLAUDE.md). Neither has been run with `astrona test`.
lab-01: old `validation.checks` (resourceExists authorizationpolicy -n istio-system) folded into the script as part of check 1.
Both graders use `istioctl` on the host (lab-01 bootstrap installs it; lab-02 assumes it is on PATH, like ATS014 labs).

## astrona.yaml entries for this module (replace the current 050-01 block)

```yaml
      - type: reading
        title: "Authorize By Source IP At The Ingress Gateway"
        path: sections/section-050/module-01/course.md
      - type: reading
        title: "Guard The Arrival Gate"
        path: sections/section-050/module-01/course-01-guard-the-arrival-gate.md
      - type: reading
        title: "Who Opened The Connection: ipBlocks"
        path: sections/section-050/module-01/course-02-who-opened-the-connection.md
      - type: reading
        title: "Trust The Right Number Of Relays"
        path: sections/section-050/module-01/course-03-trust-the-right-number-of-relays.md
      - type: reading
        title: "Block A Client Range With remoteIpBlocks"
        path: sections/section-050/module-01/course-04-block-a-client-range.md
      - type: reading
        title: Question
        path: sections/section-050/module-01/labs/lab-01/question.md
      - type: lab
        title: "Block A Client Range At The Gateway Lab"
        path: sections/section-050/module-01/labs/lab-01
        difficulty: intermediate
        estimated_duration: 15m
        topic: edge-authorization
        task_kind: build
        tags: [authorizationpolicy, ingress-gateway, remote-ip-blocks, num-trusted-proxies, deny-policy, rbac-403, proxy-config]
        learning_goals:
          - Write an AuthorizationPolicy in the gateway's namespace that selects the ingress gateway pod
          - Refuse a client range by its forwarded address with remoteIpBlocks while every other client still gets through
          - Prove from the gateway listener that it trusts one proxy hop
        resources:
          - name: "AuthorizationPolicy Source reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source
          - name: "Ingress gateway authorization"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-ingress/
          - name: "Configuring gateway network topology"
            url: https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/
      - type: reading
        title: "One Path, One Network"
        path: sections/section-050/module-01/course-05-one-path-one-network.md
      - type: reading
        title: Question
        path: sections/section-050/module-01/labs/lab-02/question.md
      - type: lab
        title: "Open One Path To One Network Lab"
        path: sections/section-050/module-01/labs/lab-02
        difficulty: intermediate
        estimated_duration: 15m
        topic: edge-authorization
        task_kind: build
        tags: [authorizationpolicy, ingress-gateway, remote-ip-blocks, paths, deny-policy, num-trusted-proxies, access-log]
        learning_goals:
          - Open one path at the ingress gateway to one network with a DENY rule and notRemoteIpBlocks
          - Keep every other path open by avoiding an ALLOW policy on the shared gateway
          - Show that a forged X-Forwarded-For entry in front of the trusted one is ignored
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Ingress gateway authorization"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-ingress/
          - name: "Configuring gateway network topology"
            url: https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-050/module-01/course-06-wrap-up.md
```

## Section README lines (`sections/section-050/README.md`, module 1 block)

- Parts list: 1. Guard The Arrival Gate (`course-01-guard-the-arrival-gate.md`),
  2. Who Opened The Connection: `ipBlocks` (`course-02-who-opened-the-connection.md`),
  3. Trust The Right Number Of Relays (`course-03-trust-the-right-number-of-relays.md`),
  4. Block A Client Range With `remoteIpBlocks` (`course-04-block-a-client-range.md`),
  5. One Path, One Network (`course-05-one-path-one-network.md`),
  6. Wrap-Up (`course-06-wrap-up.md`).
- Playground line: Istio 1.30.5 with Helm, ingress gateway `istio-ingress`
  (label `istio=ingress`) with port forwards on `127.0.0.1:8080` and
  `127.0.0.1:8443`, the Starfleet behind `starfleet.example.com` (Gateway and
  VirtualService ready), no `AuthorizationPolicy`, `numTrustedProxies` unset.
- Graded labs: lab-01 Block A Client Range At The Gateway (link `labs/lab-01/question.md`,
  not `docs/exam-question.md` any more); lab-02 Open One Path To One Network (new).

## new-data files used

None (module had no new-data).

## Open doubts to check on the cluster

1. **Helm istiod value** `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies`
   (part 3, practice.md, lab-02 install): confirm the gateway gets
   `xffNumTrustedHops: 1` after `helm upgrade --reuse-values` + gateway restart,
   and at first install in lab-02. Fallback: `podAnnotations` on the gateway
   chart (`examples/03-trusted-proxies/values-gateway-topology.yaml`), and
   change part 3 / lab-02 to match.
2. **Too low / too high direction.** I rewrote the old pages, which had it
   backwards ("too low = spoofable"). Envoy picks the Nth entry from the
   right, so too HIGH trusts a client-written entry (spoofable), too LOW
   (or 0) lands on a relay. Part 3 + part 4 demos test this with N=1 and
   two-entry headers; optionally confirm with N=2 (`values-istiod-topology-2.yaml`).
3. **Unset numTrustedProxies:** the pages say the gateway then ignores XFF and
   `remoteIpBlocks` sees the peer (127.0.0.1). The old pages said "spoofable".
   Confirm a `remoteIpBlocks` DENY 192.168.0.0/16 + XFF 192.168.5.5 gives 200
   before the setting (overview.md "Things to try").
4. **No XFF header with N=1** falls back to the peer (course-04 expects 200).
5. **Access log field:** pages say the last address on the gateway log line
   (`%DOWNSTREAM_REMOTE_ADDRESS%`) becomes the XFF-derived client once trusted
   hops are set (may print `10.1.2.3:0`). If it stays 127.0.0.1, rewrite the
   course-03/04/05 sentences to point at the XFF field instead.
6. **Old page error fixed:** old part 3 taught "ALLOW with to.paths keeps the
   rest of the gateway open". That is wrong (ALLOW refuses everything not
   matched). Part 5 and lab-02 teach DENY + notRemoteIpBlocks instead; the
   playground has the ALLOW mistake as `examples/05-.../cases/c1`.
7. **bridge `/api/v1/products` and `/api/v1/products/0`** return 200 through the
   gate with no policy (lab-02 grader and part 1/5 rely on it).
8. **Part 1 bridge log check:** confirm the gateway's 403 does not appear in
   `bridge-v1` istio-proxy log and the shuttle's direct call gets 200.
9. **HTTPS practice task 3:** policy on the gateway pod also refuses on 443;
   `curl --resolve starfleet.example.com:8443:127.0.0.1` through the astrona
   https port forward.
10. Part 1 says `*` in `paths` is only allowed at the start or end (prefix/suffix match) - standard Istio rule, quick check.
