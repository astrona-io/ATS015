# Hand-over: 040-01 Terminate TLS At The Ingress Gateway (draft, not run)

Drafted without a cluster. Every `<!-- OUTPUT PENDING: ... -->` must be
replaced with real output. Delete this file after verification.

## Playground

- Name: `ats-015-playground-040-01` (kind cluster `kind-astro-ats-015-playground-040-01`).
- `bootstrap/install-istio.sh`: Helm `istio-base` + `istiod` in `istio-system`,
  `gateway` chart released as `istio-ingress` in `istio-ingress`
  (`service.type=ClusterIP`, pod label `istio=ingress`).
- `bootstrap/deploy.sh`: `namespace.yaml`, `access-logs.yaml`, `starfleet.yaml`,
  `shuttle.yaml` (copied from ATS014 010-01 playground). No probe, no fortio.
  No certificates: the learner makes them with `openssl` into `./certs/`.
- `config.yaml` portForwards: `ingress-http` 127.0.0.1:8080 -> svc/istio-ingress:80,
  `ingress-https` 127.0.0.1:8443 -> svc/istio-ingress:443.
- `examples/01-gateway-starfleet-https.yaml`, `examples/02-virtualservice-bridge.yaml`,
  `examples/cases/c1-gateway-secret-wrong-namespace.yaml`.
- Old `bootstrap/prepare.sh` and `manifests/lab-start.yaml` deleted (git rm).

Run order on the cluster: work in one empty folder, paste the `https_status`
helper from `course.md`, then follow parts 1 -> 4. Part 3's rotation leaves
`starfleet-credential` holding the "Starfleet Fleet Two" certificate; part 4
works with either.

## OUTPUT PENDING locations, in run order

1. `course-01-give-the-gate-its-certificate.md` CA `openssl req -x509`: openssl progress or nothing
2. same, server key/CSR/sign: "Certificate request self-signature ok" + subject (wording varies by openssl)
3. same, `openssl x509 -noout -text | grep`: Issuer / Subject / DNS:starfleet.example.com
4. same, `kubectl get pods -A -l istio=ingress`: one pod in istio-ingress
5. same, `kubectl create secret tls`: secret created
6. same, go-template key list: tls.crt, tls.key
7. `course-02-open-the-https-door.md` apply Gateway: created
8. same, apply VirtualService: created
9. same, `https_status`: 200 exit=0
10. same, `https_status -v | grep subject/issuer`: subject/issuer lines
11. same, curl without `--cacert`: exit=60
12. same, `istioctl proxy-config secret deploy/istio-ingress`: ACTIVE row + default/ROOTCA rows
13. `course-03-redirect-and-rotate.md` curl port 8080 before redirect: 000 + non-zero exit (exact code unknown)
14. same, apply Gateway with port 80: configured
15. same, curl redirect: `301 -> https://starfleet.example.com:8080/productpage`
16. same, openssl rotation cert: self-signature ok + new subject
17. same, `create --dry-run | apply`: configured (maybe last-applied warning)
18. same, `https_status -v | grep subject|exit=`: new subject + 200 exit=0
19. `course-04-when-the-handshake-fails.md` secret in starfleet: created
20. same, apply wrong-namespace Gateway: configured
21. same, `https_status`: 000 exit=56 (new-data saw 56)
22. same, `proxy-config secret`: WARMING row for starfleet-credential-app-ns
23. same, `istioctl analyze -n starfleet`: IST0101 Referenced credentialName not found
24. same, re-apply good Gateway + `https_status`: configured, 200 exit=0
25. same, curl `-k` for other.example.com: 000 exit=35
26. `course-05-wrap-up.md` `astrona list` after destroy: "No astrona labs running."
27. `playground/docs/practice.md` (fresh state, Secret `starfleet-tls`): 200 exit=0, 301
28. `labs/lab-01/solution.md`: secret created; gateway created; virtualservice created; proxy-config ACTIVE row. (The tls.crt/tls.key, `https: 200`, subject/issuer and `http: 301` blocks are reused from the old guide, same app and commands; re-check them, the old page said "Expect something like".)
29. `labs/lab-02/solution.md`: step 1 curl (000 exit=35 expected); step 2 WARMING row; step 3 analyze (IST0101, maybe IST0132); step 3 `get secret -A --field-selector` + Gateway hosts; step 4 secret created; step 5 configured; step 6 ACTIVE + analyze clean + 200 exit=0.

## Labs

| Lab | metadata.name | New? | App |
| --- | --- | --- | --- |
| lab-01 Serve HTTPS At The Ingress Gateway | `ats-015-lab-040-01` (kept) | converted | own app: `tls-demo`, `booking-service`, `demo` profile gateway `istio-ingressgateway` in `istio-system` |
| lab-02 Repair The Gate's Certificate | `ats-015-lab-040-01-02` | **new** | Starfleet, Helm, gateway `istio-ingress` in `istio-ingress` |

lab-01: `bootstrap/setup.sh` split into `01-install-istio.sh` (istioctl + openssl + demo
profile) and `02-seed-workloads.sh` (manifests + `/tmp/booking.*` + sidecar restart);
`manifests/` -> `bootstrap/manifests/`; `solution/*.yaml` -> `solution/apply.sh`
(embedded self-signed cert, valid to 2036); `validate.sh` -> `validation/validate-completed.sh`
with the three `resourceExists` checks folded in and check 2 now requiring `ACTIVE`
(a WARMING row also contains the name). `docs/`, `teardown/` deleted.

lab-02: faults = Secret `starfleet-credential` in `starfleet` instead of `istio-ingress`,
and Gateway host `bridge.example.com` instead of `starfleet.example.com`. CA left in
ConfigMap `starfleet-ca` (key `ca.crt`). Config has `runtime.portForwards` 8443 -> 443.
Grader uses its own `kubectl port-forward` on 18443.

Both labs: `astrona validate` only complains about `metadata.docs.question/solution`
(expected per CLAUDE.md). Not run: `astrona test` on either lab.

## astrona.yaml entries (replace the current 040-01 block)

```yaml
      - type: reading
        title: "Terminate TLS At The Ingress Gateway"
        path: sections/section-040/module-01/course.md
      - type: reading
        title: "Give The Gate Its Certificate"
        path: sections/section-040/module-01/course-01-give-the-gate-its-certificate.md
      - type: reading
        title: "Open The HTTPS Door"
        path: sections/section-040/module-01/course-02-open-the-https-door.md
      - type: reading
        title: "Redirect And Rotate"
        path: sections/section-040/module-01/course-03-redirect-and-rotate.md
      - type: reading
        title: Question
        path: sections/section-040/module-01/labs/lab-01/question.md
      - type: lab
        title: "Serve HTTPS At The Ingress Gateway Lab"
        path: sections/section-040/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 20m
        topic: ingress-egress
        task_kind: build
        tags: [gateway, ingress-gateway, tls-termination, redirect, virtualservice, proxy-config]
        learning_goals:
          - Store a TLS certificate as a Secret in the namespace the ingress gateway pod reads from
          - Serve one host over HTTPS with a SIMPLE TLS Gateway server and a bound VirtualService
          - Redirect plain HTTP on port 80 to HTTPS with httpsRedirect
        resources:
          - name: "Secure gateways task"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
          - name: "Gateway reference (ServerTLSSettings)"
            url: https://istio.io/latest/docs/reference/config/networking/gateway/
      - type: reading
        title: "When The Handshake Fails"
        path: sections/section-040/module-01/course-04-when-the-handshake-fails.md
      - type: reading
        title: Question
        path: sections/section-040/module-01/labs/lab-02/question.md
      - type: lab
        title: "Repair The Gate's Certificate Lab"
        path: sections/section-040/module-01/labs/lab-02
        difficulty: intermediate
        estimated_duration: 20m
        topic: ingress-egress
        task_kind: troubleshooting
        tags: [gateway, ingress-gateway, tls-termination, ist0101, istioctl-analyze, proxy-config]
        learning_goals:
          - Find a TLS Secret in the wrong namespace from a WARMING secret in the gateway proxy and IST0101
          - Tell a missing certificate from a wrong SNI host by curl's exit code
          - Prove the repaired gateway serves the right certificate to a client that trusts only the lab CA
        resources:
          - name: "Secure gateways task"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
          - name: "IST0101 ReferencedResourceNotFound"
            url: https://istio.io/latest/docs/reference/config/analysis/ist0101/
          - name: "Debugging Envoy and istiod"
            url: https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
      - type: reading
        title: "Wrap-Up: Mission Debrief"
        path: sections/section-040/module-01/course-05-wrap-up.md
```

## Section README (`sections/section-040/README.md`, "### 1. Terminate TLS At The Ingress Gateway")

- Parts list: Give The Gate Its Certificate (`course-01-give-the-gate-its-certificate.md`),
  Open The HTTPS Door (`course-02-open-the-https-door.md`), Redirect And Rotate
  (`course-03-redirect-and-rotate.md`), When The Handshake Fails
  (`course-04-when-the-handshake-fails.md`), Wrap-Up (`course-05-wrap-up.md`).
- Playground line: "the Starfleet on the planet `starfleet`, Istio 1.30.5 with Helm and the
  ingress gateway `istio-ingress` in `istio-ingress`, port forwards 8080 -> 80 and 8443 -> 443;
  no certificates, Secret, `Gateway` or `VirtualService`."
- Graded labs: lab-01 link should point at `question.md` (not `docs/exam-question.md`),
  `astrona submit -c sections/section-040/module-01/labs/lab-01`; add lab-02
  "Repair The Gate's Certificate" (`labs/lab-02/question.md`).
- The intro line 5 ("Module 1 is `SIMPLE` ...") can stay.

## new-data files used (delete after verification)

From `new-data/securing-workloads/examples/04-ingress-https/`:
`01-gateway-bookinfo-https.yaml`, `02-virtualservice-bookinfo.yaml`,
`cases/c2-gateway-secret-wrong-namespace.yaml`, and the SIMPLE / redirect / case 2 /
case 3 / exit-code parts of `README.md`. `PRACTICE.md` holds only the SIMPLE task and is
fully used here. Shared with 040-02, delete only after 040-02 is done: `README.md`,
`PRACTICE.md`, `config.yaml`, `bootstrap/` (the cert script there also makes the client cert).
Not used here: `03-gateway-bookinfo-mutual.yaml`, `cases/c1-make-other-ca-client-cert.sh` (040-02).

## Open doubts to check on the cluster

1. Gateway `port.name`: I wrote it is only a label and `protocol` decides. The old page
   claimed the name prefix changes protocol handling for Gateway servers. Check.
2. `https://127.0.0.1:8443` (no SNI) against a Gateway with one specific host: does the
   handshake really fail (course-02 and course-04 say so)?
3. Wrong-namespace Secret: exit 56 (new-data) vs 35. lab-02 with both faults: I expect 35.
4. Port 80 before the redirect server exists (course-03 step 1): exact curl result.
5. `redirect_url` keeps `:8080`; status is 301.
6. `istioctl analyze` text for IST0101 on a Gateway credential, and whether lab-02 also
   shows IST0132 (VirtualService host not on the Gateway).
7. lab-02 validator: `{.hosts}` jsonpath prints `["starfleet.example.com"]` (the grep
   expects the quoted host); `kubectl get gateway.networking.istio.io` is used to avoid
   the Gateway API `gateway` short name clash.
8. lab-02 `runtime.portForwards` in a lab config: does `astrona run` start it, and does
   it recover after the gateway Service is created by the bootstrap?
9. `openssl x509 -req -extfile` and the output wording on macOS LibreSSL vs OpenSSL 3.
10. `minProtocolVersion` / `--tls-max 1.2` claim (course-04 paragraph, overview idea).
11. `kubectl get secret -A --field-selector metadata.name=starfleet-credential` works.
12. `astrona port-forward start -c .` exists (overview troubleshooting, copied from new-data).
13. lab-01 solution: one `kubectl port-forward ... 8443:443 8080:80` command instead of two.
