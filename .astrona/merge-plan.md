# Merge plan: new-data import and full rework (temporary)

Working notes for the branch `course/merge-new-data`. Delete this file when
every row in the status table is `done`.

Decisions taken with the maintainer (2026-10-09):

1. **Sample app:** playgrounds and course pages move to **the Starfleet**
   (see `CLAUDE.md`, "The playground fleet"). Existing graded labs and
   capstones keep their small apps (`booking-service`,
   `notification-service`, `tester`). New labs use the Starfleet.
2. **Lab layout:** every lab and capstone moves to the ATS014 layout:
   `question.md`, `solution.md`, `README.md`, `bootstrap/`, `solution/apply.sh`,
   `validation/validate-completed.sh`, `config.yaml` with
   `metadata.docs.question` and `metadata.docs.solution`.
3. **new-data lab 05 (egress TLS origination)** becomes a new module
   **040-04**, with a new graded lab.
4. **Verification:** everything is run on a real `kind` cluster, one cluster
   at a time. Real output only.

The reference course for every format question is `../ATS014` (same
maintainer, already reworked). Copy its patterns: playground
`config.yaml` / `bootstrap/install-istio.sh` / `bootstrap/deploy.sh` /
`docs/overview.md` / `docs/practice.md` / `examples/`, lab layout, landing
page, parts, `## Your mission` sections, wrap-up page, `astrona.yaml` format.
Copy the fleet manifests from
`../ATS014/sections/section-010/module-01/playground/bootstrap/manifests/`
(`starfleet.yaml`, `shuttle.yaml`, `probe.yaml`, `namespace.yaml`,
`access-logs.yaml`), `../ATS014/sections/section-000/module-01/playground/bootstrap/manifests/outpost.yaml`
and `../ATS014/sections/section-040/module-02/playground/bootstrap/manifests/fortio.yaml`.

## Where each new-data lab goes

new-data lives in `new-data/securing-workloads/`. Rename everything to the
Starfleet while merging (`bookinfo`→`starfleet`, `productpage`→`bridge`,
`details`→`cargo`, `reviews`→`scout`, `ratings`→`navcom`, `curl`→`shuttle`,
`httpbin`→`probe`, `legacy`/`curl`→`outpost`/`drifter`,
`bookinfo-*` service accounts→`starfleet-*`, `bookinfo.example.com`→`starfleet.example.com`).
If new-data and an existing page teach the same thing, keep **one**
explanation (the clearer, verified one) and drop the other.

| new-data | Goes to | What to merge |
| --- | --- | --- |
| `README.md` (topic overview) | wrap-ups and parts of 010-03, 020-02, 030-01 | "order to apply things", "which rule wins", "errors and what they mean" table: merge each fact into the part that teaches it; no separate page |
| `examples/01-mtls` 01, 02, 04, c2 | 010-02 playground `examples/01-mtls/`, parts on modes and scopes | namespace STRICT, workload PERMISSIVE, mesh-wide STRICT, namespace beats mesh |
| `examples/01-mtls` c1 | 010-02 | `portLevelMtls` keyed by the **container** port (8080, not Service 8000), needs a `selector` |
| `examples/01-mtls` 03, c3, c4 | 010-02 (client side) | `DestinationRule` `tls.mode` `ISTIO_MUTUAL` / `DISABLE`, auto mTLS, `503 UC`, server `DISABLE` |
| `examples/01-mtls/PRACTICE.md` | 010-02 playground `docs/practice.md` | |
| `examples/02-authorization` 01, 02, c3 | 020-01 playground and parts | allow-nothing, allow shuttle GET on probe, `rules: [{}]` allows all |
| `examples/02-authorization` 04, c1 | 020-01 | least privilege for the whole fleet (per service account), allow a whole namespace |
| `examples/02-authorization` 03, c2, c4 | 020-02 playground and parts | DENY a path, DENY with `notMethods`, DENY with empty rule beats every ALLOW |
| `examples/02-authorization/PRACTICE.md` | 020-01 / 020-02 `docs/practice.md` (split by topic) | |
| `examples/03-jwt-authentication` 01, 02, c1, c2 | 030-01 | `RequestAuthentication`, require a token (401 vs 403), `fromParams`, "token required" as DENY |
| `examples/03-jwt-authentication` 03, c3, c4 | 030-02 | require a group claim, a claim no token has, one public path |
| `examples/03-jwt-authentication/PRACTICE.md` | 030-01 / 030-02 `docs/practice.md` | |
| `examples/04-ingress-https` 01, 02, c2, c3 | 040-01 | `SIMPLE` TLS with `credentialName`, HTTPS redirect, secret in the wrong namespace (`IST0101`, `WARMING`), wrong SNI host |
| `examples/04-ingress-https` 03, c1 | 040-02 | `MUTUAL` TLS, client certificate from another CA |
| `examples/04-ingress-https/PRACTICE.md` | 040-01 / 040-02 `docs/practice.md` | |
| `examples/05-egress-tls-origination` (all) | **new module 040-04** | `ServiceEntry` with `targetPort`, `DestinationRule` `tls.mode: SIMPLE`, `subjectAltNames`, missing `targetPort`, HTTP features on an HTTPS service; new graded lab `ats-015-lab-040-04-01` |

Modules with no new-data (010-01, 010-03, 030-02 partly, 040-03, 050-01,
060-01) still get the full rework: Starfleet playground, Plain English with
the space glossary, wrap-up, lab conversion.

When a module is done, delete the new-data files it used. When every
new-data file is used, delete `new-data/`.

## Steps for one module

Work on exactly one module at a time. Read `CLAUDE.md` first, all of it.

1. **Read** the module (landing, parts, playground, labs) and the matching
   new-data files. Read the ATS014 equivalents named above for format.
2. **Playground.** Rebuild it the ATS014 way: `config.yaml` (kind runtime,
   `portForwards` if a gateway or the bridge page is used),
   `bootstrap/install-istio.sh` (Helm, Istio 1.30.5; add the
   `istio-ingress` gateway chart, ambient charts, or `meshConfig` values
   only when the module needs them), `bootstrap/deploy.sh`,
   `bootstrap/manifests/` (fleet files plus any module precondition, for
   example a `STRICT` `PeerAuthentication`), `examples/` (renamed new-data
   YAML), `docs/overview.md`, `docs/practice.md`, `README.md`. Keep
   `metadata.name` `ats-015-playground-<section>-<module>`. Delete the old
   `bootstrap/prepare.sh` and `manifests/lab-start.yaml`.
3. **Run it.** `astrona run -c sections/<...>/playground` (local path, the
   changes are not pushed). Run every command the parts will show, and
   capture the real output. Destroy it when done:
   `astrona destroy ats-015-playground-<section>-<module>`.
4. **Write the reading.** Landing page (`course.md`): goals, what to know
   first, what is in the playground, the order of the parts,
   `<!-- astrona:playground -->` on its own line. No links to other modules
   or sections. Parts: Plain English, space glossary, real example before the
   rule, Starfleet commands, `<!-- astrona:playground:renew -->` once before
   the first hands-on step, "Save this as / Apply it / Then check the result",
   `## Common pitfalls` `> [!WARNING]` at the end, Mermaid without HTML,
   no "Prerequisite / Next" lines, no "Part N shows". Split or merge parts at
   natural seams (5 to 8 minutes, at most about 8 command blocks). Add a
   wrap-up part (`course-0N-wrap-up.md`): recap per part with links, missions
   table, "Check yourself" questions, clean-up (`astrona list`,
   `astrona destroy <playground>`).
5. **Labs.** Convert every lab of the module to the new layout (see
   `CLAUDE.md`). `question.md` = the exam task (from
   `docs/exam-question.md`, with the scenario from `docs/case-study.md`
   folded in as one or two sentences, and anything needed from
   `docs/prerequisites.md`). `solution.md` = the walkthrough (from
   `docs/step-by-step-guide.md`), rewritten in Plain English, real output.
   `validate.sh` → `validation/validate-completed.sh`; fold the
   `validation.checks` of `config.yaml` into that script.
   `solution/*.yaml` → `solution/apply.sh`. Bootstrap scripts →
   `bootstrap/01-install-istio.sh`, `bootstrap/02-seed-workloads.sh`,
   `bootstrap/manifests/`. Keep `metadata.name`. Delete `docs/`,
   `teardown/`, `manifests/`, the old `validate.sh` once moved. Run
   `astrona validate -c <lab>` and `astrona test -c <lab>`; both must pass.
   Create a new lab where a part teaches a gradeable skill no lab covers
   (at least 040-04).
6. **Mission sections.** The part a lab tests ends with
   `## Your mission: <lab title>` (copy the ATS014 wording: stop playground,
   run, read `question.md`, submit, destroy lab, start playground).
7. **`astrona.yaml`.** Update only this module's entries in the
   `module-0N0` block: landing, parts, `Question` reading + `type: lab`
   entry (all metadata fields) right after the tested part, wrap-up last.
8. **Section README.** Update this module's lines in
   `sections/section-0N0/README.md` (Plain English, no cross-section links).
9. **Status.** Set the module's row below to `done`, with a one-line note
   (what was merged, new labs, anything not verified and why).

## Status

| Item | Status | Note |
| --- | --- | --- |
| CLAUDE.md, merge plan | done | |
| astrona.yaml to ATS014 format | done | lab metadata fields added per module |
| Mission Briefing (`sections/intro/`) | done | adapted from ATS014 |
| 010-01 Inspect Workload Identity And Certificates | done | Starfleet playground (fleet manifests copied from ATS014, outpost/drifter added, fortio annotation dropped), 3 parts + wrap-up rewritten, lab-01 converted (own app, astrona test PASS); trust domain change described only |
| 010-02 Enforce mTLS With PeerAuthentication At Three Scopes | done | new-data 01-mtls merged; Starfleet playground, 6 parts + wrap-up checked on 1.30.5; lab-01 converted (own app, now Helm), new lab-02 (portLevelMtls) and lab-03 (503 UC); all three astrona test PASS |
| 010-03 Migrate A Namespace From PERMISSIVE To STRICT mTLS | done | new-data README order-to-apply merged; Starfleet playground, 4 parts + wrap-up checked on 1.30.5 (native sidecar shown in INIT column); port exception cut to one sentence (010-02 owns it), draft lab-02 dropped; lab-01 kept (own app, demo profile), astrona test PASS; leftover files to delete listed in the 010-03 commit message |
| 010 capstone | todo | |
| 020-01 Authorize HTTP Traffic Between Workloads | done | new-data 02-authorization ALLOW parts merged (DENY files, README and bootstrap left for 020-02); Starfleet playground, 6 parts + wrap-up checked on 1.30.5 (from_fortio now prints `Code NNN`, port-forward bypasses the bridge guard noted); lab-01 converted (own app, demo profile, grader now retries), new lab-02 (repair guest lists); both astrona test PASS |
| 020-02 DENY Policies And Evaluation Order | done | new-data 02-authorization DENY files merged; Starfleet playground, 6 parts + wrap-up checked on 1.30.5 (DENY TCP-port warning shown, fortio via `fortio load`, waits now "up to a minute"); lab-01 converted (own app, demo profile), new lab-02 (probe read-only with notMethods); both astrona test PASS |
| 020 capstone | todo | |
| 030-01 Authenticate End Users With JWT | done | new-data 03-jwt 01, 02, c1, c2 merged (README, PRACTICE, bootstrap left for 030-02); Starfleet playground, 4 parts + wrap-up checked on 1.30.5 (istiod inlines the JWKS as `localJwks`, DENY TCP-port warning shown, waits now "about a minute"); lab-01 converted (own app, now Helm), new lab-02 (fromParams + DENY); both astrona test PASS |
| 030-02 Authorize On JWT Claims | done | new-data 03-jwt 03, c3, c4, PRACTICE merged; Starfleet playground with `probe-jwt` RequestAuthentication, 4 parts + wrap-up checked on 1.30.5 (claim names show under `payload` in proxy-config, not `request.auth.claims`); lab-01 converted (own app, now Helm, grader retries), new lab-02 (claim typo + public path); both astrona test PASS |
| 030 capstone | todo | |
| 040-01 Terminate TLS At The Ingress Gateway | done | new-data 04-ingress-https 01, 02, c2 merged (README, PRACTICE, config, bootstrap left for 040-02); Starfleet playground with Helm gateway, 4 parts + wrap-up checked on 1.30.5 (wrong-namespace Secret and wrong SNI both give curl exit 35, not 56; port forward restarts after a failed handshake); lab-01 converted (own app, grader retries 90 s), new lab-02 (Secret in wrong namespace + wrong host, IST0101 + IST0132); both astrona test PASS |
| 040-02 Require Client Certificates At The Edge | done | new-data 04-ingress-https 03, c1 merged; Starfleet playground with Helm gateway, 4 parts + wrap-up checked on 1.30.5 (MUTUAL with no CA = `-cacert` WARMING, everyone refused with exit 35, analyze silent; Envoy ssl stats are not exposed, so the reason is read from the `connection` debug log; knocks reordered because a refused handshake restarts the 8443 forward); lab-01 converted (own app, demo profile, grader retries), new lab-02 (wrong CA in the gate's secret); both astrona test PASS |
| 040-03 TLS Passthrough Instead Of Termination | done | no new-data; Starfleet playground with the vault (`tls-backend`) and Helm gateway, 5 parts + wrap-up checked on 1.30.5 (an `http` block or a host typo removes the port 443 listener entirely; typo gives IST0132, `http` block nothing; `HTTPS` + `PASSTHROUGH` still passes through, so taught as misleading, not broken; webhook rejects `sniHosts` outside `hosts`); lab-01 converted (own app, demo profile, listener on pod port 8443, grader retries), new lab-02 (host typo + `http` block, istioctl pinned); both astrona test PASS |
| 040-04 Originate TLS For External Services (new) | todo | new-data 05-egress |
| 040 capstone | todo | |
| 050-01 Authorize By Source IP At The Ingress Gateway | todo | |
| 050 capstone | todo | |
| 060-01 Authorization In Ambient Mode, L4 And L7 | todo | |
| 060 capstone | todo | |
| README.md, section READMEs final pass | todo | |
| Delete `new-data/` | todo | |
