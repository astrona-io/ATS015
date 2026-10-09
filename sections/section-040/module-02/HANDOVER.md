# Hand-over: 040-02 Require Client Certificates At The Edge

Drafted without a cluster. The verify agent runs everything, replaces every
`<!-- OUTPUT PENDING: ... -->` line with a ` ```text ` block of real output,
fixes any prose the output contradicts, then deletes this file.

## Playground

- Name: `ats-015-playground-040-02` (`astrona run -c sections/section-040/module-02/playground`).
- Installs: Istio 1.30.5 with Helm (`istio-base`, `istiod` in `istio-system`,
  `gateway` chart as `istio-ingress` in `istio-ingress`, Service type ClusterIP,
  pod label `istio=ingress`), mesh-wide access logs, namespace `starfleet`
  (injection) with the Starfleet (bridge, cargo, scout v1-v3, navcom) and
  `shuttle`. No probe, no fortio (not needed here).
- `runtime.portForwards`: `ingress-http` 127.0.0.1:8080 -> svc/istio-ingress:80,
  `ingress-https` 127.0.0.1:8443 -> svc/istio-ingress:443.
- No certificates, secret, Gateway or VirtualService. The learner makes the
  certificates with openssl in a local `certs/` folder (course-01 commands),
  and pastes the `https_status` helper from `course.md`.
- `astrona validate -c .../playground` passes.

## OUTPUT PENDING locations, in run order

Run in one working folder (certs/ is relative). Paste `https_status` from course.md first.

Playground, course parts:

1. `course-01-issue-the-fleet-badges.md` line ~54: `mkdir -p certs` + CA openssl (files exist; openssl prints progress or nothing).
2. `course-01` ~74: server CSR + sign with SAN (stderr "Certificate request self-signature ok").
3. `course-01` ~94: client CSR + sign.
4. `course-01` ~108: `openssl x509 -subject -issuer` on the client cert (format depends on local openssl; OpenSSL 3 vs LibreSSL on macOS).
5. `course-01` ~120: `openssl verify -CAfile ...` two `: OK` lines.
6. `course-02-make-the-gate-ask-for-a-badge.md` ~42: `kubectl create secret generic starfleet-credential-mutual` in istio-ingress.
7. `course-02` ~53: go-template key list (ca.crt, tls.crt, tls.key).
8. `course-02` ~103: apply `virtualservice-bridge.yaml`.
9. `course-02` ~136: apply `gateway-starfleet.yaml` (MUTUAL).
10. `course-02` ~177: `https_status` no cert -> expect `000 exit=56`; with client cert -> `200 exit=0`.
11. `course-03-turn-away-strangers-and-prove-it.md` ~28: other-ca + other-client openssl (stderr not silenced here, unlike the new-data script).
12. `course-03` ~39: stranger -> `000 exit=56`; client -> `200 exit=0`.
13. `course-03` ~58: `pilot-agent request GET stats | grep ssl.fail_verify_(no_cert|error)` (trim to the 443 listener lines; say so if trimmed).
14. `course-03` ~76: `istioctl proxy-config secret deploy/istio-ingress -n istio-ingress` (expect `kubernetes://starfleet-credential-mutual` Cert Chain ACTIVE and `...-cacert` CA ACTIVE, plus default, ROOTCA).
15. `course-03` ~91: `proxy-config listener --port 443 -o json | grep requireClientCertificate`.
16. `course-04-two-secret-layouts-and-what-a-badge-proves.md` ~33: create `starfleet-credential-split` (tls) and `starfleet-credential-split-cacert` (generic).
17. `course-04` ~68: apply `gateway-starfleet.yaml` with credentialName `starfleet-credential-split` (configured).
18. `course-04` ~79: three `https_status` calls + `proxy-config secret | grep split`.

Playground practice (`playground/docs/practice.md`, fresh state: run `kubectl delete gateways.networking.istio.io,virtualservice --all -n starfleet` first):

19. practice ~32: create secret `starfleet-mtls`.
20. practice ~71: apply Gateway (443 MUTUAL + 80 httpsRedirect).
21. practice ~105: apply VirtualService.
22. practice ~116: no cert / cert / plain HTTP -> expect `000 exit=56`, `200 exit=0`, `301`.

Lab 01 (`labs/lab-01/solution.md`, its own app, demo profile, /tmp files):

23. ~15: `openssl x509 -in /tmp/client.crt -subject -issuer`.
24. ~32: create secret `booking-credential-mtls` in istio-system.
25. ~80: apply `gateway-booking.yaml`.
26. ~112: apply `virtualservice-booking.yaml`.
27. ~122: `proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential-mtls`.
28. ~133: `proxy-config listener ... -o json | grep requireClientCertificate` (no `--port`: the old validate.sh says `--port 443` misses the chain on the demo gateway, whose listener is 8443).
29. ~151: port-forward + two curls (`no cert: 000`, `with cert: 200`).
(The key list output at Step 2 was kept from the old page: same app and command.)

Lab 02 (`labs/lab-02/solution.md`, new, Starfleet):

30. ~20: knock helper, partner -> expect `000 exit=56`, stranger -> `200 exit=0`.
31. ~33: subject of `ca.crt` in the secret (`other-ca`).
32. ~43: `proxy-config secret` before the fix.
33. ~59: recreate secret via `--dry-run=client -o yaml | kubectl apply -f -` (check for the last-applied warning).
34. ~71: `proxy-config secret | grep cacert` after (serial changed).
35. ~81: partner / none / stranger -> `200 exit=0`, `000 exit=56`, `000 exit=56`.

## Labs

| Lab | metadata.name | New? | App |
| --- | --- | --- | --- |
| `labs/lab-01` Require Client Certificates At The Edge | `ats-015-lab-040-02` (kept) | converted | own app `mtlsedge-demo` / `booking-service`, istioctl `demo` profile, PKI written to `/tmp` (fixed, committed PEMs kept from the old setup.sh) |
| `labs/lab-02` Fix The Gate's Trusted Badge Office | `ats-015-lab-040-02-02` | **new** | Starfleet, Helm + `istio-ingress`; certificates generated by `bootstrap/03-seed-fault.sh` into `/tmp/ats-015-lab-040-02-02/` (CA keys deleted after signing) |

Both: `astrona validate` reports only the known `metadata.docs.question/solution` "unknown field" complaints (keep them, per CLAUDE.md). `astrona test` not run (no cluster).

lab-01 changes: old `validation.checks` (secret exists, gateway exists) folded into
`validation/validate-completed.sh` (new check 2 also verifies the Gateway server is 443/MUTUAL/booking-credential-mtls and the VirtualService exists). `solution/apply.sh` builds the secret from `/tmp` files (no base64 copy). Deleted `docs/`, `teardown/`, `manifests/`, `bootstrap/setup.sh`, `solution/*.yaml`, `solution/README.md`. The openssl `apt-get` auto-install from the old setup.sh was dropped (only a warning remains).

## astrona.yaml entries for this module (replace the current 040-02 block)

```yaml
      - type: reading
        title: "Require Client Certificates At The Edge"
        path: sections/section-040/module-02/course.md
      - type: reading
        title: "Issue The Fleet's Badges"
        path: sections/section-040/module-02/course-01-issue-the-fleet-badges.md
      - type: reading
        title: "Make The Gate Ask For A Badge"
        path: sections/section-040/module-02/course-02-make-the-gate-ask-for-a-badge.md
      - type: reading
        title: Question
        path: sections/section-040/module-02/labs/lab-01/question.md
      - type: lab
        title: "Require Client Certificates At The Edge Lab"
        path: sections/section-040/module-02/labs/lab-01
        difficulty: intermediate
        estimated_duration: 20m
        topic: ingress-egress
        task_kind: build
        tags: [gateway, ingress-gateway, tls-termination, mutual-tls-edge, proxy-config]
        learning_goals:
          - Build a gateway secret with tls.crt, tls.key and ca.crt in the gateway pod's namespace
          - Configure a Gateway server with tls.mode MUTUAL that refuses clients without a certificate
          - Prove from the gateway listener that a client certificate is required
        resources:
          - name: "Secure gateways: mutual TLS ingress gateway"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/#configure-a-mutual-tls-ingress-gateway
          - name: "Gateway reference: ServerTLSSettings"
            url: https://istio.io/latest/docs/reference/config/networking/gateway/#ServerTLSSettings
          - name: "Debugging Envoy and istiod"
            url: https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
      - type: reading
        title: "Turn Away Strangers And Prove It"
        path: sections/section-040/module-02/course-03-turn-away-strangers-and-prove-it.md
      - type: reading
        title: Question
        path: sections/section-040/module-02/labs/lab-02/question.md
      - type: lab
        title: "Fix The Gate's Trusted Badge Office Lab"
        path: sections/section-040/module-02/labs/lab-02
        difficulty: intermediate
        estimated_duration: 20m
        topic: ingress-egress
        task_kind: troubleshooting
        tags: [gateway, ingress-gateway, mutual-tls-edge, client-certificates, proxy-config]
        learning_goals:
          - Find which certificate authority a MUTUAL gateway trusts from its secret and its proxy
          - Replace the CA in the gateway secret so only clients from the right CA get in
          - Prove that a client from another CA and a client without a certificate are refused
        resources:
          - name: "Secure gateways: mutual TLS ingress gateway"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/#configure-a-mutual-tls-ingress-gateway
          - name: "Debugging Envoy and istiod"
            url: https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
      - type: reading
        title: "Two Secret Layouts And What A Badge Proves"
        path: sections/section-040/module-02/course-04-two-secret-layouts-and-what-a-badge-proves.md
      - type: reading
        title: "Wrap-Up"
        path: sections/section-040/module-02/course-05-wrap-up.md
```

Tag note: CLAUDE.md's tag and topic lists are still the ATS014 (traffic management)
lists. `mutual-tls-edge` and `client-certificates` are proposed new tags; add them
to the list (or swap for whatever security tag list ATS015 settles on) before
writing the entries. `topic: ingress-egress` is the closest existing topic.

## Section README lines to update (`sections/section-040/README.md`)

Replace this module's lines with something like:

- **Module 2: Require Client Certificates At The Edge.** Make your own CA with
  `openssl`, give the ingress gateway a secret with `tls.crt`, `tls.key` and
  `ca.crt`, switch it to `MUTUAL`, see clients without a certificate (or with
  one from another CA) turned away in the handshake, and prove the check from
  the gateway's proxy. Also covers the separate `-cacert` secret layout.
  Missions: Require Client Certificates At The Edge (build), Fix The Gate's
  Trusted Badge Office (troubleshooting, new).

## new-data files used (delete after verification)

- `new-data/securing-workloads/examples/04-ingress-https/03-gateway-bookinfo-mutual.yaml`
- `new-data/securing-workloads/examples/04-ingress-https/cases/c1-make-other-ca-client-cert.sh`
- The MUTUAL half of `new-data/securing-workloads/examples/04-ingress-https/README.md`
  (mutual TLS section, mode table, case 1, MUTUAL cheat-sheet line). Shared with 040-01:
  delete `README.md`, `PRACTICE.md`, `config.yaml`, `bootstrap/` only once 040-01 is done too.
- `PRACTICE.md` has **no MUTUAL task** (only SIMPLE + redirect). `playground/docs/practice.md`
  here is a new MUTUAL task written for this module; its solution still needs a real run.

## Open doubts to check on the cluster

1. **The old "fails open" claim was dropped.** The old pages said a `MUTUAL` gateway
   with a missing/misnamed `ca.crt` serves TLS and accepts everyone, with
   `requireClientCertificate: false`. From the Istio source, `MUTUAL` always sets
   `requireClientCertificate: true` and asks SDS for `<name>-cacert`; a missing CA
   should leave that resource `WARMING` and refuse **every** client. The new text
   says that (course-03 "A gate that cannot load its badges turns every visitor
   away, the good ones too"; overview "Things to try" bullet on `create secret tls`).
   Please test: MUTUAL + secret without `ca.crt` -> `proxy-config secret` row state
   and `https_status` with a good client cert. Fix the text if the result differs.
2. **Key names `cert` / `key` / `cacert`.** course-02 says Istio also reads these
   older names. Believed true (generic secret format); verify or remove the sentence.
3. **curl exit 56** for no cert and for the other-CA cert through the Helm gateway
   (new-data shows 56; check both).
4. **Envoy stats names** `ssl.fail_verify_no_cert` / `ssl.fail_verify_error` on the
   gateway, and that `pilot-agent request GET stats` works in the `istio-ingress`
   pod. Also the claim that the access log has **no** line for a refused handshake
   (course-03, wrap-up). If either is wrong, change course-03's "Ask the gate why"
   section and wrap-up question 4.
5. **`--port 443` on the Helm gateway** listener (course-03 step 15). The Helm
   gateway's HTTP listener is on 80 (ATS014 output), so 443 should match; the demo
   install in lab-01 uses 8443, which is why lab-01 drops `--port`.
6. **Split layout** (`<name>-cacert` with key `ca.crt` beside a `kubernetes.io/tls`
   secret) in 1.30.5, and that `proxy-config secret` shows both rows ACTIVE.
7. **`-cacert` row naming when the CA is inside the same secret** (course-03 says
   Istio always uses `<name>-cacert`; ATS014 080-02 output supports this).
8. **No restart needed** after changing `ca.crt` (lab-02 Step 3, overview last bullet).
9. **astrona port forward restart** after a refused handshake (landing page and
   overview say astrona restarts it; taken from new-data README). The lab
   question tells learners to restart their own `kubectl port-forward`; lab-02's
   grader restarts its own forward between knocks.
10. **lab-02 grader**: `openssl crl2pkcs7 ... | openssl pkcs7 -print_certs` exists on the
    grading machine's openssl (macOS LibreSSL too). The grader runs openssl and curl on
    the host and reads `/tmp/ats-015-lab-040-02-02/`, same model as lab-01's `/tmp` files.
11. **lab-01 Step 1 output** format of `-subject -issuer` differs between OpenSSL 1.1,
    3.x and LibreSSL; pick what the test machine prints.
12. **Playground 8443 and lab ports**: both labs tell learners to `kubectl port-forward ... 8443:443`.
    This only works if `astrona stop` of the playground frees 127.0.0.1:8443. Check; if
    not, change the labs to another local port.
13. The `X-Forwarded-Client-Cert` statements in course-04 are prose only (no command).
