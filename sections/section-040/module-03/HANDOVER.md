# Hand-over: 040-03 TLS Passthrough Instead Of Termination (draft, not run)

Delete this file after verification. Nothing here was run on a cluster.

## Playground

`ats-015-playground-040-03` (`playground/`). `bootstrap/install-istio.sh`: Helm `istio-base` + `istiod`
(istio-system) + `gateway` chart released as `istio-ingress` in `istio-ingress` (ClusterIP, pod label
`istio=ingress`), Istio 1.30.5, pinned to context `kind-astro-ats-015-playground-040-03`.
`bootstrap/deploy.sh`: `namespace.yaml`, `access-logs.yaml`, `starfleet.yaml` (-n starfleet), `shuttle.yaml`
(copied from ATS014 010-01), `tls-backend.yaml` (the vault: nginx + initContainer `alpine/openssl` self-signed
cert `CN=vault.starfleet.example.com/O=vault`, Service `tls-backend` port 8443 named `tls`, in `starfleet`),
`bridge-gateway.yaml` (precondition: Gateway `starfleet-gateway` HTTP 80 host `starfleet.example.com` +
VirtualService `bridge` /productpage + /static -> bridge:9080). portForwards: 127.0.0.1:8080 -> svc/istio-ingress:80,
127.0.0.1:8443 -> svc/istio-ingress:443. `examples/` 01-03 + `cases/` c1-c3. `docs/overview.md`, `docs/practice.md`
(own task, no new-data). Old `bootstrap/prepare.sh` and `manifests/lab-start.yaml` deleted.

Learner helpers (landing page): `tls_status <host> [path]` (curl -sk --resolve to 127.0.0.1:8443) and
`show_certificate <host>` (openssl s_client -servername | openssl x509 -subject -fingerprint -sha256).

## OUTPUT PENDING, in run order

Playground (one run covers parts 1-5, in this order):

1. course-01:56 `kubectl get pods,svc -n starfleet -l app=tls-backend` - pod 2/2, Service 8443/TCP
2. course-01:69 cert from vault disk via openssl - subject + sha256 fingerprint (keep it for step 8)
3. course-01:81 shuttle -> `https://tls-backend:8443/` - "vault ended TLS itself"
4. course-02:19 `tls_status vault...` before any object - expect 000
5. course-02:57 apply gateway-vault.yaml - created
6. course-02:114 apply virtualservice-tls-backend.yaml - created
7. course-02:132 tls_status + curl body - 200 / "vault ended TLS itself"
8. course-03:21 `show_certificate vault...` - same fingerprint as step 2
9. course-03:37 `proxy-config listener ... --port 443` - SNI match, cluster destination
10. course-03:53 `proxy-config routes` - bridge http.80 only, nothing for vault
11. course-03:66 tls_status + gateway access log - TCP-style line, SNI, cluster
12. course-04:59 http-block VS: tls_status + `istioctl analyze -n starfleet` - 000 + whatever analyze says
    (then re-apply good VS)
13. course-04:110 gateway host typo: tls_status + listener - 000, no vault SNI (then re-apply good Gateway)
14. course-04:135 curl to 127.0.0.1 + `openssl s_client -noservername` - 000 + handshake failure lines
15. course-05:24 openssl req (self-signed starfleet.example.com with -addext SAN)
16. course-05:35 create secret tls starfleet-credential -n istio-ingress
17. course-05:78 apply gateway-starfleet.yaml (80 + 443 SIMPLE) - configured
18. course-05:93 tls_status both hosts + show_certificate both - 200/200, O=starfleet-gate vs O=vault
19. course-05:105 proxy-config routes - https.443 route for starfleet.example.com, none for vault
20. course-06:128 `astrona list` after destroy - "No astrona labs running."

Practice (playground, after deleting vault-gateway, VS tls-backend and the 443 server on starfleet-gateway):

21. playground/docs/practice.md:39 openssl + secret edge-credential
22. playground/docs/practice.md:142 two statuses + two certificates

lab-01 (`ats-015-lab-040-03`, own app; steps 1 and 4 curl output reused from the old verified guide):

23. labs/lab-01/solution.md:56 apply Gateway - created
24. labs/lab-01/solution.md:97 apply VirtualService - created
25. labs/lab-01/solution.md:132 listener port 443 + routes grep/echo

lab-02 (`ats-015-lab-040-03-02`, new):

26. labs/lab-02/solution.md:18 000
27. labs/lab-02/solution.md:30 listener with typo host + http block
28. labs/lab-02/solution.md:39 Gateway hosts jsonpath + VirtualService spec
29. labs/lab-02/solution.md:76 Gateway configured
30. labs/lab-02/solution.md:111 VirtualService configured
31. labs/lab-02/solution.md:127 200, body, subject O=vault
32. labs/lab-02/solution.md:136 the echo line (no route)

## Labs

| Lab | metadata.name | New? | App | Placed after |
| --- | --- | --- | --- | --- |
| lab-01 Route An Encrypted Stream By SNI | `ats-015-lab-040-03` | converted (kept name, app, demo profile, istioctl install) | `passthrough-demo` / `secure.ica.local` / `istio-ingressgateway` in istio-system | course-03 |
| lab-02 Fix The Gate That Routes Nothing | `ats-015-lab-040-03-02` | **new** (troubleshooting) | Starfleet + vault, Helm, `istio-ingress` | course-04 |

lab-01: old docs/, teardown/, manifests/, validate.sh, bootstrap/setup.sh, solution/*.yaml removed;
`validation.checks` (resourceExists Gateway/VirtualService) folded into the script header (the script already
fails on missing objects). Both labs need `astrona validate` (fails only on the expected
`metadata.docs.question/solution` unknown-field messages) and `astrona test`.

## astrona.yaml entries (replace the module-03 block inside module-040)

```yaml
      - type: reading
        title: "TLS Passthrough Instead Of Termination"
        path: sections/section-040/module-03/course.md
      - type: reading
        title: "What A Proxy Can See"
        path: sections/section-040/module-03/course-01-what-a-proxy-can-see.md
      - type: reading
        title: "Open A Gate That Does Not Decrypt"
        path: sections/section-040/module-03/course-02-open-a-gate-that-does-not-decrypt.md
      - type: reading
        title: "Prove Who Opened The Envelope"
        path: sections/section-040/module-03/course-03-prove-who-opened-the-envelope.md
      - type: reading
        title: Question
        path: sections/section-040/module-03/labs/lab-01/question.md
      - type: lab
        title: "Route An Encrypted Stream By SNI Lab"
        path: sections/section-040/module-03/labs/lab-01
        difficulty: intermediate
        estimated_duration: 15m
        topic: edge-tls
        task_kind: build
        tags: [gateway, virtualservice, tls-passthrough, sni, ingress-gateway, proxy-config]
        learning_goals:
          - Expose a backend through the ingress gateway with a TLS PASSTHROUGH server and no credential
          - Route an encrypted stream with a VirtualService tls block that matches sniHosts
          - Prove from the served certificate and the gateway's routes that the backend ended TLS
        resources:
          - name: "Ingress gateway without TLS termination"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-sni-passthrough/
          - name: "Gateway reference: ServerTLSSettings"
            url: https://istio.io/latest/docs/reference/config/networking/gateway/#ServerTLSSettings
          - name: "VirtualService reference: TLSRoute"
            url: https://istio.io/latest/docs/reference/config/networking/virtual-service/#TLSRoute
      - type: reading
        title: "When The Stream Has Nowhere To Go"
        path: sections/section-040/module-03/course-04-when-the-stream-has-nowhere-to-go.md
      - type: reading
        title: Question
        path: sections/section-040/module-03/labs/lab-02/question.md
      - type: lab
        title: "Fix The Gate That Routes Nothing Lab"
        path: sections/section-040/module-03/labs/lab-02
        difficulty: intermediate
        estimated_duration: 20m
        topic: edge-tls
        task_kind: troubleshooting
        tags: [gateway, virtualservice, tls-passthrough, sni, connection-reset, proxy-config, openssl]
        learning_goals:
          - Find a passthrough setup that routes nothing from the gateway's listener instead of the status code
          - Replace an http block with a tls block that matches sniHosts, and align the Gateway hosts with it
          - Prove the repaired host returns 200 with the backend's own certificate
        resources:
          - name: "Ingress gateway without TLS termination"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-sni-passthrough/
          - name: "Debugging Envoy and istiod (proxy-config)"
            url: https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
          - name: "VirtualService reference: TLSRoute"
            url: https://istio.io/latest/docs/reference/config/networking/virtual-service/#TLSRoute
      - type: reading
        title: "One Gate, Two Modes"
        path: sections/section-040/module-03/course-05-one-gate-two-modes.md
      - type: reading
        title: "Wrap-Up"
        path: sections/section-040/module-03/course-06-wrap-up.md
```

## Section README (sections/section-040/README.md, "### 3. TLS Passthrough Instead Of Termination")

- Part list: 1 What A Proxy Can See, 2 Open A Gate That Does Not Decrypt, 3 Prove Who Opened The Envelope,
  4 When The Stream Has Nowhere To Go, 5 One Gate, Two Modes, 6 Wrap-Up (new file names above).
- Playground line: "namespace `starfleet` with the Starfleet, the shuttle and the vault (`tls-backend`, an nginx
  that makes its own certificate and ends TLS itself on port 8443). The bridge is already behind the gate over
  HTTP; the gate is reached on 127.0.0.1:8080 and 127.0.0.1:8443. No TLS secret: passthrough needs none."
- Labs: lab-01 link to `./module-03/labs/lab-01/question.md` (docs/exam-question.md no longer exists), and a new
  line for lab-02 "Fix The Gate That Routes Nothing".
- The section-wide "No load balancer on kind ... port-forward svc/istio-ingressgateway" note is now wrong for this
  playground (Helm gateway `istio-ingress`, astrona portForwards).

## new-data used

None (no new-data maps to 040-03).

## Open doubts to check on the cluster

1. Gateway + VS with an `http` block on a PASSTHROUGH server: does 1.30.5 `istioctl analyze` stay quiet? Text says
   "may stay quiet"; tighten once known. Does curl really print 000?
2. Validation webhook: is `sniHosts` required to be one of the VirtualService's own `hosts` (course-04 says
   Istio checks this at apply time, lab-02 solution Common Mistakes says so too)? If not, reword both.
3. Gateway host typo (`valt`): what does `proxy-config listener --port 443` show - no 443 listener, or a filter
   chain for valt with no destination? course-04 and lab-02 step 2 describe "vault missing from MATCH".
4. `proxy-config listener --port 443` table format for passthrough: is MATCH "SNI: <host>" and DESTINATION
   "Cluster: outbound|8443||tls-backend..."? Adjust course-03 text if not.
5. Gateway access log line for passthrough: confirm the fields described (method/path "-", SNI, cluster).
6. HTTPS (SIMPLE, starfleet-gateway) and TLS PASSTHROUGH (vault-gateway) servers on port 443 from two different
   Gateway objects on one gateway pod: confirm they merge without conflict (course-05) and also in one Gateway
   object (practice.md).
7. Gateway -> tls-backend hop: the gateway likely wraps the passthrough stream in mesh mTLS (auto mTLS) to the
   vault's sidecar. Text only claims the inner client session stays sealed; check nothing contradicts.
8. `openssl req -addext` on macOS (LibreSSL) - works? `openssl x509 -fingerprint -sha256` output format.
   `kubectl exec ... cat tls.crt | openssl x509` from the nginx:1.27-alpine container.
9. lab-02 solution: `kubectl apply` of the fixed VS must drop the seeded `http` block (3-way merge with
   last-applied). solution/apply.sh relies on it; the grader fails if `spec.http` remains.
10. lab-02 grader: `curl -v` subject line format "O=vault" vs "O = vault" (regex allows both); runs on the host.
11. course-05 "Only connection metrics such as istio_tcp_connections_opened_total remain" - check the gateway
    really reports TCP metrics for passthrough.
