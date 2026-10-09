# Hand-over: 010-03 Migrate A Namespace From PERMISSIVE To STRICT mTLS

Drafted without a cluster. The verify agent runs everything, replaces every
`<!-- OUTPUT PENDING: ... -->` line with real output, and deletes this file.

## 1. Files to delete (the drafting agent was not allowed to delete)

The permission system refused `rm` / `git rm`, so these old files are still in
the tree and must be removed:

- `course-01-measuring-with-telemetry.md`, `course-02-exceptions-and-meshing.md`,
  `course-03-enforcing-and-rolling-back.md` (replaced by the six new parts)
- `playground/bootstrap/prepare.sh`, `playground/manifests/` (whole folder)
- `labs/lab-01/docs/` (whole folder), `labs/lab-01/teardown/`,
  `labs/lab-01/manifests/` (copied to `labs/lab-01/bootstrap/manifests/`),
  `labs/lab-01/validate.sh` (now `validation/validate-completed.sh`),
  `labs/lab-01/bootstrap/setup.sh` (now `01-install-istio.sh` + `02-seed-workloads.sh`),
  `labs/lab-01/solution/01-namespace.yaml`, `02-outside-client.yaml`,
  `03-peerauthentication.yaml`, `solution/README.md` (now `solution/apply.sh`)

## 2. Playground

- Name: `ats-015-playground-010-03` (kind, no port forwards).
- `bootstrap/install-istio.sh`: Helm, Istio 1.30.5, `istio-base` + `istiod` only.
- `bootstrap/deploy.sh`: namespace `starfleet` (injection on) + mesh-wide access
  logs, the Starfleet, `shuttle`, `probe` v1/v2 (Service 8000 -> container 8080),
  namespace `outpost` (no injection) with the `drifter` (1/1).
  No `PeerAuthentication`: starfleet starts `PERMISSIVE`. No Prometheus, no Kiali.
- Manifests copied from ATS014 (010-01 playground and 000-01 `outpost.yaml`);
  only header comments of `probe.yaml` and `outpost.yaml` were changed.
- `examples/01-migrate-to-strict/`: 01 PERMISSIVE, 02 STRICT, 03 probe port
  exception (8080), `cases/c1` wrong port (8000), `cases/c2` cargo DR `DISABLE`.

## 3. OUTPUT PENDING locations, in run order

One playground run covers parts 1 to 5 in order (state carries over: part 2
leaves `default` = PERMISSIVE, part 3 deletes the probe policy, part 4 meshes
the drifter, part 5 leaves STRICT).

Playground:
1. `course-01-count-the-plain-signals.md:55` — 10 shuttle 200 / 10 drifter 200
2. `course-01...:74` — `plain_signals`: `mutual_tls 10`, `none 10`
3. `course-01...:95` — source labels of the `none` lines (`unknown`?)
4. `course-01...:110` — cargo inbound log, 2 lines (+ drifter pod `-o wide`)
5. `course-02-write-down-where-you-stand.md:52` — `kubectl get peerauthentication`
6. `course-02...:97` — STRICT drill: shuttle 200, drifter 000 + exit 56
7. `course-02...:114` — rollback: configured + drifter 200
8. `course-03-keep-one-port-open.md:85` — wrong port 8000: drifter 000 + exit 56
9. `course-03...:122` — right port 8080: drifter 200
10. `course-03...:136` — delete probe policy
11. `course-04-bring-the-drifter-into-the-fleet.md:48` — label, still 1 container
12. `course-04...:62` — restart, 2 containers
13. `course-04...:94` — measure again: none unchanged, mutual_tls +5
14. `course-05-switch-to-strict-for-good.md:41` — STRICT: shuttle 200, drifter 200
15. `course-05...:56` — `istioctl x describe pod` on cargo
16. `course-05...:96` — DR DISABLE: shuttle 503 + `UC` log line
17. `course-05...:111` — DR deleted, shuttle 200
18. `course-06-wrap-up.md:121` — `astrona list` after destroy
19. `playground/docs/practice.md:49`, `:77`, `:131` — task 1 and task 2 (task 2
    needs the drifter back without sidecar and starfleet STRICT)

Lab 02 (`labs/lab-02/solution.md`): `:15`, `:28`, `:59`, `:72`.
Lab 01 (`labs/lab-01/solution.md`): `:23`, `:59`, `:69`, `:86`, `:122`, `:131`.

## 4. Labs

| Lab | metadata.name | App | New? |
| --- | --- | --- | --- |
| `labs/lab-01` Migrate A Namespace To STRICT mTLS | `ats-015-lab-010-03` (kept) | own app: `migrate-demo` (booking/notification-service, tester), `outside` (outside-client); demo profile via istioctl | converted |
| `labs/lab-02` Keep One Port Open For The Drifter | `ats-015-lab-010-03-02` | Starfleet + outpost/drifter; Helm install | **new** (troubleshooting: port exception keyed on Service port 8000) |

`astrona validate` on both labs reports only the known `metadata.docs.question`
/ `solution` "unknown field" errors (keep them, per CLAUDE.md). The playground
validates clean. `astrona test` not run (no cluster allowed).

lab-01 validation: old `validate.sh` checks plus the folded `resourceExists
peerauthentication/default -n migrate-demo` (check 0).

## 5. astrona.yaml entries for this module (replace the current module-03 block)

`topic` / `tags` below are proposals: the topic and tag lists in CLAUDE.md are
the ATS014 (traffic management) lists and have no mTLS values. Tags not in the
list are marked `# new`; add them to the list or replace them.

```yaml
      - type: reading
        title: "Migrate A Namespace From PERMISSIVE To STRICT mTLS"
        path: sections/section-010/module-03/course.md
      - type: reading
        title: "Count The Plain Signals"
        path: sections/section-010/module-03/course-01-count-the-plain-signals.md
      - type: reading
        title: "Write Down Where You Stand"
        path: sections/section-010/module-03/course-02-write-down-where-you-stand.md
      - type: reading
        title: "Keep One Port Open"
        path: sections/section-010/module-03/course-03-keep-one-port-open.md
      - type: reading
        title: Question
        path: sections/section-010/module-03/labs/lab-02/question.md
      - type: lab
        title: "Keep One Port Open For The Drifter Lab"
        path: sections/section-010/module-03/labs/lab-02
        difficulty: intermediate
        estimated_duration: 15m
        topic: mtls                      # new topic value, see note above
        task_kind: troubleshooting
        tags: [peerauthentication, port-level-mtls, strict-mtls, connection-reset, sidecar-injection]   # port-level-mtls, strict-mtls, connection-reset are new
        learning_goals:
          - Keep one container port open to plain signals with portLevelMtls while the workload stays STRICT
          - Tell a container port from a Service port and fix an exception that silently does nothing
        resources:
          - name: "PeerAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/peer_authentication/
          - name: "Mutual TLS migration"
            url: https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
      - type: reading
        title: "Bring The Drifter Into The Fleet"
        path: sections/section-010/module-03/course-04-bring-the-drifter-into-the-fleet.md
      - type: reading
        title: "Switch To STRICT For Good"
        path: sections/section-010/module-03/course-05-switch-to-strict-for-good.md
      - type: reading
        title: Question
        path: sections/section-010/module-03/labs/lab-01/question.md
      - type: lab
        title: "Migrate A Namespace To STRICT mTLS Lab"
        path: sections/section-010/module-03/labs/lab-01
        difficulty: intermediate
        estimated_duration: 20m
        topic: mtls                      # new topic value, see note above
        task_kind: migration
        tags: [peerauthentication, sidecar-injection, strict-mtls, mtls-metrics, proxy-config]   # strict-mtls, mtls-metrics are new
        learning_goals:
          - Prove from the receiving proxy's counters that plain signals still arrive
          - Bring an unmeshed caller into the mesh by labelling its namespace and restarting it
          - Switch a namespace to STRICT mTLS in an order that breaks no caller
        resources:
          - name: "Mutual TLS migration"
            url: https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
          - name: "PeerAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/peer_authentication/
          - name: "Istio standard metrics"
            url: https://istio.io/latest/docs/reference/config/metrics/
          - name: "Sidecar injection"
            url: https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-010/module-03/course-06-wrap-up.md
```

## 6. Section README lines (`sections/section-010/README.md`, module 3 block)

- Parts list: replace the three old parts with
  1. Count The Plain Signals (`course-01-count-the-plain-signals.md`)
  2. Write Down Where You Stand (`course-02-write-down-where-you-stand.md`)
  3. Keep One Port Open (`course-03-keep-one-port-open.md`)
  4. Bring The Drifter Into The Fleet (`course-04-bring-the-drifter-into-the-fleet.md`)
  5. Switch To STRICT For Good (`course-05-switch-to-strict-for-good.md`)
  6. Wrap-Up: Mission Debrief (`course-06-wrap-up.md`)
- Playground line: "namespace `starfleet` (the Starfleet, no `PeerAuthentication`,
  so `PERMISSIVE`) and namespace `outpost` without injection, whose `drifter` still
  sends plain signals and is moved into the mesh during the module."
- Graded labs: link `labs/lab-02/question.md` (Keep One Port Open For The Drifter)
  and `labs/lab-01/question.md` (Migrate A Namespace To STRICT mTLS) instead of
  `docs/exam-question.md`; submit with `astrona submit -c sections/section-010/module-03/labs/lab-0N`.

## 7. new-data used

- `new-data/securing-workloads/README.md` section 3 (order to apply / remove,
  PeerAuthentication only) -> part 2 "The safe order", part 5 rollback.
- `new-data/securing-workloads/README.md` section 5, rows "connection reset
  (curl exit 56)" and "503 `UC`" -> part 5 error table, part 2.
- The README is shared with 020-02 and 030-01: delete it only when they are done.
- `examples/01-mtls/cases/c1` (port exception on 8080) was used as the model
  for the probe exception; it belongs to 010-02, so do not delete it from here.

## 8. Open doubts to check on the cluster

1. `portLevelMtls` keyed on the Service port (8000) really does nothing on
   1.30.5 (drifter still reset). Lab 02 depends on this. If istiod maps
   Service port to target port, lab 02 and part 3 need a redesign.
2. `source_workload` / `source_workload_namespace` for the drifter's plain
   signals are `unknown` (part 1).
3. The inbound access log's `%REQUESTED_SERVER_NAME%` field shows
   `outbound_.9080_._.cargo.starfleet.svc.cluster.local` for mTLS and `-` for
   plain signals, and the downstream address is the drifter pod IP (part 1).
4. `plain_signals` (sed/awk on `reporter="destination"` lines) sums correctly
   on macOS and Linux, and cargo has no `reporter="source"` lines that matter.
5. `istioctl x describe pod` on 1.30.5 still prints the "Effective
   PeerAuthentication" block (part 5, lab-01 solution). If not, use the
   15006 inbound listener (`istioctl proxy-config listener ... --port 15006 -o json`)
   like lab-01 check 5 does, and rewrite the text.
6. DR `tls.mode: DISABLE` against STRICT cargo gives `503` with flag `UC` in the
   shuttle's log (part 5), not `URX` or another flag.
7. A STRICT refusal of the drifter prints `000` and `command terminated with
   exit code 56` (parts 2, 3; lab 02).
8. Lab-01 check 5 (listener on 8084 via the full dump) is unchanged from the
   old lab; lab-02 validator untested.
9. Lab-01 `estimated_duration` 20m and lab-02 15m are guesses.
