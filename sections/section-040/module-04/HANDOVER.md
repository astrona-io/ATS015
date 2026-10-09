# HANDOVER: module 040-04 Originate TLS For External Services (new module)

Drafted without a cluster. The verify agent runs everything, replaces every
`<!-- OUTPUT PENDING: ... -->` line with real output, writes `astrona.yaml`
and the section README lines, then deletes this file and commits.

## Playground

- Name: `ats-015-playground-040-04`, path `sections/section-040/module-04/playground`.
- Installs: Istio 1.30.5 with Helm (`istio-base` + `istiod`, no gateways,
  `ALLOW_ANY` default), namespace `starfleet` (injection on), mesh-wide
  access logs (`Telemetry` `mesh-default`), the `shuttle` client only.
  The full Starfleet (bridge, cargo, scout, navcom) is NOT deployed: nothing
  in the module uses it (same choice as ATS014 070-02). Add
  `starfleet.yaml` to `bootstrap/manifests/` and `deploy.sh` if the
  maintainer wants it anyway.
- Needs outbound internet (httpbin.org ports 80 and 443; practice.md uses www.google.com).
- `examples/01-egress-tls-origination/`: new-data 01, 02, cases c1, c2, c3 with
  `namespace: bookinfo` -> `starfleet` (names `httpbin-org` unchanged).
- Nothing old to delete (new module: no `prepare.sh` / `lab-start.yaml`).

## OUTPUT PENDING locations, in run order

Paste the helpers first (`status_and_time`, `last_log_line`, defined in each part).

1. `course-01-who-seals-the-signal.md` line ~42: `status_and_time https://httpbin.org/get` + `last_log_line` -> 200, `"- - -" 0`, `:443`, `PassthroughCluster`.
2. `course-01-who-seals-the-signal.md` line ~54: `curl -s http://httpbin.org/get | grep '"url"'` -> `"url": "http://httpbin.org/get"`.
3. `course-02-...` line ~73: after applying the ServiceEntry: 400, log `"GET /get HTTP/1.1" 400`, upstream `:443`, `outbound|80||httpbin.org`.
4. `course-02-...` line ~118: after the DestinationRule: `"url": "https://..."`, log 200 via `:443`, then `https://` call 200.
5. `course-02-...` line ~135: `istioctl proxy-config cluster ... --fqdn httpbin.org` (two STRICT_DNS clusters, DR `httpbin-org.starfleet`) + port 80 json grep (`envoy.transport_sockets.tls`, `"sni": "httpbin.org"`).
6. `course-03-check-the-planets-id-card.md` line ~62: wrong SAN -> 503, `URX,UF`, `CERTIFICATE_VERIFY_FAILED` (shorten, say so).
7. `course-03-...` line ~112: correct SAN -> 200 with time, `"url": "https://httpbin.org/get"`.
8. `course-04-a-seal-on-the-wrong-channel.md` line ~57: SE without targetPort -> 503 `URX,UF` `WRONG_VERSION_NUMBER`, upstream `:80` (shorten, say so).
9. `course-04-...` line ~76: SE fixed -> 200, upstream `:443`.
10. `course-05-use-what-you-won.md` line ~54: VS timeout 2s: `/delay/4` -> 504 ~2.0s; `/get` -> 200.
11. `course-05-...` line ~62: `kubectl logs ... --tail=2` -> `504 UT response_timeout` ~2000 ms, then the 200 line.
12. `course-06-wrap-up.md` line ~84: `astrona list` after destroy -> "No astrona labs running." (or whatever it prints).
13. `playground/docs/practice.md` line ~69: google SE + DR -> 200, log `"GET / HTTP/1.1" 200`, `:443`, `outbound|80||www.google.com`.

Lab `labs/lab-01/solution.md` (run in the lab cluster):

14. line ~16: Step 1 url `http://` + log `"- - -"` / `PassthroughCluster`.
15. line ~24: first `astrona submit` -> `FAIL: ServiceEntry 'httpbin-org' not found in starfleet`.
16. line ~68: Step 2 -> 400 + log `via_upstream` `:443`.
17. line ~122: Step 4 -> `"url": "https://..."` + log 200 `:443`.
18. line ~132: `https://httpbin.org/get` -> 200.
19. line ~145: port 80 json grep, then `grep -c` on port 443 -> 0.
20. line ~155: final `astrona submit` -> PASS line.

## Labs

| Lab | Name | New? | App |
| --- | --- | --- | --- |
| `labs/lab-01` "Seal The Signal To An Outside Planet Lab" | `ats-015-lab-040-04-01` | **new** | Starfleet `shuttle` in `starfleet`, calls httpbin.org (needs internet) |

`astrona validate -c sections/section-040/module-04/labs/lab-01` reports only
the expected `metadata.docs.question/solution` "unknown field" errors
(CLAUDE.md: keep them). Playground validates clean. `astrona test` not run.

## astrona.yaml entries (append inside the `module-040` block, after the module-03 entries and before the capstone)

```yaml
      - type: reading
        title: "Originate TLS For External Services"
        path: sections/section-040/module-04/course.md
      - type: reading
        title: "Who Seals The Signal"
        path: sections/section-040/module-04/course-01-who-seals-the-signal.md
      - type: reading
        title: "Chart The Planet And Seal The Signal"
        path: sections/section-040/module-04/course-02-chart-the-planet-and-seal-the-signal.md
      - type: reading
        title: "Check The Planet's ID Card"
        path: sections/section-040/module-04/course-03-check-the-planets-id-card.md
      - type: reading
        title: Question
        path: sections/section-040/module-04/labs/lab-01/question.md
      - type: lab
        title: "Seal The Signal To An Outside Planet Lab"
        path: sections/section-040/module-04/labs/lab-01
        difficulty: intermediate
        estimated_duration: 20m
        topic: external-services
        task_kind: build
        tags: [serviceentry, destinationrule, tls-origination, external-services, access-log, proxy-config]
        learning_goals:
          - Let the sidecar originate TLS with a ServiceEntry targetPort and a DestinationRule in SIMPLE mode
          - Make the sidecar check the server's certificate name with subjectAltNames
          - Prove from the server's answer, the access log and proxy-config that only port 80 is sealed
        resources:
          - name: "Egress TLS origination task"
            url: https://istio.io/latest/docs/tasks/traffic-management/egress/egress-tls-origination/
          - name: "ServiceEntry reference"
            url: https://istio.io/latest/docs/reference/config/networking/service-entry/
          - name: "DestinationRule reference"
            url: https://istio.io/latest/docs/reference/config/networking/destination-rule/
      - type: reading
        title: "A Seal On The Wrong Channel"
        path: sections/section-040/module-04/course-04-a-seal-on-the-wrong-channel.md
      - type: reading
        title: "Use What You Won"
        path: sections/section-040/module-04/course-05-use-what-you-won.md
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-040/module-04/course-06-wrap-up.md
```

Also consider updating the `module-040` `description` (it names only the three
Gateway modes) to mention TLS origination for outside services.

## Section README lines (`sections/section-040/README.md`)

- Intro: "Three modules, one per `Gateway` TLS mode" becomes four modules; add
  one sentence: the fourth module is about signals leaving the mesh, where the
  sidecar adds the TLS seal (TLS origination).
- "What You Will Master": add
  - A `ServiceEntry` port `80` with `targetPort: 443` and a `DestinationRule` `tls.mode: SIMPLE`, so the sidecar seals an app's plain `http://` call.
  - `subjectAltNames` to check an outside server's certificate name, and the three failures `400`, `WRONG_VERSION_NUMBER` and `CERTIFICATE_VERIFY_FAILED`.
- "The Learning Path": add

```markdown
### 4. Originate TLS For External Services
*   **Module Reader:** **[Module 4: Originate TLS For External Services](./module-04/course.md)**
    Deep-dive parts, in reading order:
    1. [Who seals the signal](./module-04/course-01-who-seals-the-signal.md)
    2. [Chart the planet and seal the signal](./module-04/course-02-chart-the-planet-and-seal-the-signal.md)
    3. [Check the planet's ID card](./module-04/course-03-check-the-planets-id-card.md)
    4. [A seal on the wrong channel](./module-04/course-04-a-seal-on-the-wrong-channel.md)
    5. [Use what you won](./module-04/course-05-use-what-you-won.md)
    6. [Wrap-up](./module-04/course-06-wrap-up.md)
*   **Hands-on Playground:** `sections/section-040/module-04/playground` — namespace `starfleet` with the `shuttle` client, no gateway, outbound internet to `httpbin.org`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-04/playground
    ```
*   **Graded lab:** **[Seal The Signal To An Outside Planet](./module-04/labs/lab-01/)** — read the
    [question](./module-04/labs/lab-01/question.md), solve it, then
    ```bash
    astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-04/labs/lab-01
    astrona submit -c sections/section-040/module-04/labs/lab-01
    ```
```

(Match whatever format the other reworked modules end up using in that README.)

## new-data files used (delete after verification)

`new-data/securing-workloads/examples/05-egress-tls-origination/` — all of it:
`README.md`, `PRACTICE.md`, `config.yaml`, `01-serviceentry-httpbin-org.yaml`,
`02-destinationrule-httpbin-org-tls.yaml`, `cases/c1-destinationrule-wrong-san.yaml`,
`cases/c2-serviceentry-without-target-port.yaml`,
`cases/c3-virtualservice-httpbin-org-timeout.yaml`, `bootstrap/` (install-istio.sh,
deploy.sh, manifests/access-logs.yaml, curl-client.yaml, httpbin.yaml,
namespace.yaml; replaced by the ATS014 fleet manifests).

## Open doubts to check on the cluster

1. **Top-level `tls` breaks the app's own `https://` calls** (course-02 pitfall,
   lab question point 4, grader message, solution step 3). Not in new-data;
   expected: port 443 cluster gets TLS, app TLS inside sidecar TLS fails
   (curl exit 35). Confirm, or soften the wording.
2. **App `https://` still 200 with the port-80-only DR** (course-02 check, grader
   check 9). new-data says so; confirm.
3. **`URX` meaning** in course-03 ("gave up after its retries or connection
   attempts ran out"): check against the real log flags (new-data showed
   `URX,UF`).
4. **Wrong `sni` not caught** (course-03 table/text): taken from new-data's test,
   not re-run. Optional: set `sni: wrong.example.com` and confirm 200.
5. **`caCertificates` unset -> default public trust store** (course-03): relies
   on `VERIFY_CERTIFICATE_AT_CLIENT` default true in 1.30. `istioctl analyze`
   may print `IST0129`; not shown in the pages.
6. **Grader SAN check**: `grep -A8 -i SubjectAltNames` on the port 80 cluster
   JSON must find `httpbin.org` (Envoy field `matchTypedSubjectAltNames`,
   matcher `exact`). Confirm the JSON shape; adjust the grep if needed.
7. **`istioctl proxy-config cluster` table**: DESTINATION RULE column text
   (`httpbin-org.starfleet`) and TYPE `STRICT_DNS` in the course-02 hint.
8. **`credentialName` for `MUTUAL` on a sidecar reads the calling workload's
   namespace** (course-05 table and pitfall). From the DestinationRule
   reference; not run (no mTLS partner in the playground).
9. **Timeout VS without a port in the destination** (course-05, new-data c3):
   new-data measured 504 at 2.0s; confirm the log flag `UT` and cluster
   `outbound|80||httpbin.org`.
10. **Grader access-log grep** expects `"GET /get HTTP/1.1" 200`,
    `outbound|80||httpbin.org` and an upstream ending `:443"` on one line.
    Confirm the field order in the default Envoy log format.
11. Lab `README.md`/`question.md` use `estimated_duration` front matter as in
    ATS014 lab-03; run `astrona test -c sections/section-040/module-04/labs/lab-01`.
