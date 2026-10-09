# Capstones hand-over (draft, not verified on a cluster)

All six section capstones are converted to the ATS014 lab layout:
`README.md` (with `estimated_duration`), `question.md`, `solution.md`,
`bootstrap/01-install-istio.sh`, `bootstrap/02-seed-workloads.sh`,
`bootstrap/manifests/`, `solution/apply.sh`,
`validation/validate-completed.sh` and `config.yaml` (`metadata.docs.question` /
`solution`, `testing.init`, `validation.scripts`). `docs/`, `teardown/`,
`manifests/`, `bootstrap/setup.sh`, `solution/*.yaml` and the old `validate.sh`
are deleted. `metadata.name` and the lab's own small app are unchanged.

`astrona validate -c <lab>` reports only the 2 known problems on every
capstone: `unknown field "solution"` / `"question"` in `metadata.docs`. The
ATS014 reference capstone gets the same 2 problems, and CLAUDE.md says to keep
these names. With the `docs` block removed, every capstone reports
"Lab config is valid". Nothing was run on a cluster: no `astrona run` and no
`astrona test`.

Shared changes:

- Istio is installed with `istioctl` (`demo` profile; `ambient` for 060), as
  CLAUDE.md says for graded labs. The workloads are applied in
  `02-seed-workloads.sh` after Istio, so sidecar injection works without the
  old restart.
- `solution/apply.sh` applies the reference YAML with heredocs and ends with
  `sleep 15` (ATS014 pattern).
- Outputs reused from the old `docs/step-by-step-guide.md` files, for commands
  that did not change, are assumed to be real. The verify agent should still
  compare them.

---

## 010: `ats-015-capstone-010`

Path: `sections/section-010/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`:

- Step 1, the `pilot-agent request GET stats/prometheus` count of
  `connection_security_policy`. The old command ran `pilot-agent` in the
  `booking-service` container (`-c booking-service`), where it does not exist.
  It is now `-c istio-proxy`.

Reused output: Step 2 (pod containers), Step 3 (`outside -> booking: 200`),
Step 4 (SAN line), Step 6 (the three calls).

Validator: I folded in the old `config.yaml` checks. There is now a check for a
`PeerAuthentication` named `default` in `istio-system`, and one for at least one
`AuthorizationPolicy` in `identity-demo`. `question.md` now says the policy
must be named `default`.

```yaml
      - type: reading
        title: Question
        path: sections/section-010/capstone/labs/lab-01/question.md
      - type: lab
        title: "Turn On Mesh-Wide mTLS Without Stranding A Caller Capstone Lab"
        path: sections/section-010/capstone/labs/lab-01
        difficulty: advanced
        estimated_duration: 45m
        topic: mtls
        task_kind: migration
        tags: [peerauthentication, authorizationpolicy, mtls-strict, mtls-scopes, sidecar-injection, spiffe, principals, openssl]
        learning_goals:
          - Bring a plain-text caller into the mesh before requiring STRICT mTLS for the whole mesh
          - Read a workload identity from its live certificate and allow only that principal
          - Tell a 403 from the authorization policy apart from a dropped connection
        resources:
          - name: "PeerAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/peer_authentication/
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "Mutual TLS migration"
            url: https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
```

## 020: `ats-015-capstone-020`

Path: `sections/section-020/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`:

- Step 1, the new check after `allow-nothing` (`tester POST /book`, expect `403`).

Reused output: Step 5 (the six calls).

Validator: check 2 now reads `-o json` with Python's `json` module instead of
PyYAML (`import yaml`), because PyYAML may be missing on the grading machine.
The logic is unchanged.

```yaml
      - type: reading
        title: Question
        path: sections/section-020/capstone/labs/lab-01/question.md
      - type: lab
        title: "Close A Namespace And Reopen Two Doors Capstone Lab"
        path: sections/section-020/capstone/labs/lab-01
        difficulty: advanced
        estimated_duration: 40m
        topic: authorization
        task_kind: build
        tags: [authorizationpolicy, default-deny, allow-nothing, deny-policy, principals, paths, methods, evaluation-order]
        learning_goals:
          - Close a namespace with an allow-nothing policy and reopen exactly two calls
          - Allow one call by service account identity rather than by namespace
          - Prove a DENY backstop wins over an ALLOW policy for the same paths
        resources:
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
          - name: "HTTP traffic authorization"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-http/
          - name: "Explicit deny"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-deny/
```

## 030: `ats-015-capstone-030`

Path: `sections/section-030/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`:

- Step 4, the six token requests. The old command had a bug. It escaped
  `\$TOKEN` inside `sh -c` in the `tester` pod, where `TOKEN` is not set, so
  the token headers were sent empty. Its old output cannot be trusted. The new
  command uses a `send_signal` helper that expands the token in the reader's
  terminal.

Reused output: Step 1 (decoded claims), Step 2 (`no token: 200`).

```yaml
      - type: reading
        title: Question
        path: sections/section-030/capstone/labs/lab-01/question.md
      - type: lab
        title: "Require A Token And Split Access By Claim Capstone Lab"
        path: sections/section-030/capstone/labs/lab-01
        difficulty: advanced
        estimated_duration: 40m
        topic: jwt
        task_kind: build
        tags: [requestauthentication, authorizationpolicy, jwt, jwks, request-principals, jwt-claims, jwt-401, rbac-403]
        learning_goals:
          - Validate tokens from one issuer and make a valid token required
          - Allow an admin path only for tokens whose groups claim contains group1
          - Explain which object returns 401 and which returns 403
        resources:
          - name: "RequestAuthentication reference"
            url: https://istio.io/latest/docs/reference/config/security/request_authentication/
          - name: "Authorization with JWT"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/
          - name: "Authorization policy conditions"
            url: https://istio.io/latest/docs/reference/config/security/conditions/
```

## 040: `ats-015-capstone-040`

Path: `sections/section-040/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`:

- Step 1, `kubectl -n istio-system create secret tls booking-credential ...`.

Reused output: Step 4 (certificate subjects, `200`s and `http: 301`).

Changes:

- `solution/apply.sh` no longer ships the committed private key from the old
  `solution/01-credential.yaml`. It builds the Secret from `/tmp/booking.crt`
  and `/tmp/booking.key`, the files `02-seed-workloads.sh` creates. If they are
  missing, it makes new ones with `openssl`. So `astrona test` needs `openssl`
  on the machine that runs it.
- The two VirtualServices are now two files in `solution.md`
  (`virtualservice-booking.yaml`, `virtualservice-passthrough.yaml`).
- Possible addition, not done: the new module 040-04 (originate TLS for
  external services). The capstone could get a fourth part, for example a
  `ServiceEntry` plus a `DestinationRule` with `tls.mode: SIMPLE` towards an
  outside host, checked from inside the mesh. That needs egress to the
  internet and its own grader checks.

```yaml
      - type: reading
        title: Question
        path: sections/section-040/capstone/labs/lab-01/question.md
      - type: lab
        title: "Terminate And Pass Through TLS On One Gateway Capstone Lab"
        path: sections/section-040/capstone/labs/lab-01
        difficulty: advanced
        estimated_duration: 45m
        topic: edge-tls
        task_kind: build
        tags: [gateway, virtualservice, ingress-gateway, tls-termination, tls-passthrough, sni, https-redirect, credential-name]
        learning_goals:
          - Serve one hostname with TLS termination and another with TLS passthrough on the same port
          - Route terminated traffic with an http block and passthrough traffic with a tls block on sniHosts
          - Prove which certificate each hostname serves, and redirect plain HTTP to HTTPS
        resources:
          - name: "Gateway reference"
            url: https://istio.io/latest/docs/reference/config/networking/gateway/
          - name: "Secure gateways"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
          - name: "Ingress gateway without TLS termination"
            url: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-sni-passthrough/
```

## 050: `ats-015-capstone-050`

Path: `sections/section-050/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`:

- Step 1, which is new. It reads `xffNumTrustedHops` from the gateway's
  listener dump. The old step grepped the `istio` ConfigMap for
  `gatewayTopology`, which the current bootstrap no longer sets.

Reused output: Step 4 (the five requests). The only change is that the helper
was renamed from `call` to `send_signal`. Its `-w` format and the printed text
are the same.

```yaml
      - type: reading
        title: Question
        path: sections/section-050/capstone/labs/lab-01/question.md
      - type: lab
        title: "Block A Range And Fence The Admin Path Capstone Lab"
        path: sections/section-050/capstone/labs/lab-01
        difficulty: intermediate
        estimated_duration: 30m
        topic: edge-authorization
        task_kind: build
        tags: [authorizationpolicy, ingress-gateway, deny-policy, remote-ip-blocks, num-trusted-proxies, paths, rbac-403]
        learning_goals:
          - Block a client address range at the ingress gateway with a DENY policy on remoteIpBlocks
          - Restrict one path to an office range with notRemoteIpBlocks without closing other paths
        resources:
          - name: "Ingress gateway authorization"
            url: https://istio.io/latest/docs/tasks/security/authorization/authz-ingress/
          - name: "Network topologies and numTrustedProxies"
            url: https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/
          - name: "AuthorizationPolicy reference"
            url: https://istio.io/latest/docs/reference/config/security/authorization-policy/
```

## 060: `ats-015-capstone-060`

Path: `sections/section-060/capstone/labs/lab-01`

OUTPUT PENDING in `solution.md`: every step. That is Step 1 (ztunnel workloads,
gateways), Step 2 (`GET` before the waypoint), Step 3
(`istioctl waypoint apply --enroll-namespace --wait`, gateway, namespace
labels), Step 4 (the four calls) and Step 5 (ztunnel policy, waypoint RBAC).

Rewritten to match the grader. The old docs asked for an L4 `selector` policy,
with `other-client` getting `000`. Commit `1c5e81a` had already changed the
validator and the solution. They now expect `targetRefs` only, no `selector`
policy, the RBAC filter on the waypoint, and `other-client` getting `403`. The
docs were never updated. `question.md` and `solution.md` now follow the
grader. `question.md` also says the waypoint must be named `waypoint`, because
the grader reads `deploy/waypoint`. I fixed three stale messages in the
validator ("enforceable at L4", "expected a refused connection").
`solution/apply.sh` now labels the namespace with
`istio.io/use-waypoint=waypoint`. Before, it re-applied the Namespace object.

```yaml
      - type: reading
        title: Question
        path: sections/section-060/capstone/labs/lab-01/question.md
      - type: lab
        title: "Enforce Request Rules Through A Waypoint Capstone Lab"
        path: sections/section-060/capstone/labs/lab-01
        difficulty: advanced
        estimated_duration: 40m
        topic: ambient
        task_kind: build
        tags: [ambient, waypoint, ztunnel, l7-policy, target-refs, authorizationpolicy, ztunnel-config, gateway-api]
        learning_goals:
          - Deploy a waypoint and enrol a namespace so its traffic goes through it
          - Attach an identity, method and path rule to the waypoint with targetRefs
          - Show which component holds the policy with ztunnel-config and the waypoint's proxy-config
        resources:
          - name: "Use Layer 7 features"
            url: https://istio.io/latest/docs/ambient/usage/l7-features/
          - name: "Configure waypoint proxies"
            url: https://istio.io/latest/docs/ambient/usage/waypoint/
          - name: "Layer 4 security policy"
            url: https://istio.io/latest/docs/ambient/usage/l4-policy/
```

---

## Doubts

1. **Lab titles.** `astrona.yaml` still has the old titles ("Workload Identity
   And Mutual TLS Capstone" and so on). The entries above suggest
   mission-style titles ending in "Capstone Lab", to match ATS014. Choose one
   set and keep README headings and `astrona.yaml` the same.
2. **060 teaching goal changed.** The capstone no longer splits the rule
   across ztunnel and a waypoint. Only the waypoint enforces it. This matches
   the verified grader, but the maintainer should confirm it is the wanted
   lesson. The section's landing page or README may still describe the old
   L4 + L7 split.
3. **050 `numTrustedProxies` location.** The bootstrap sets it as the
   gateway's `proxy.istio.io/config` annotation. Commit `01af598` verified that
   this takes effect. CLAUDE.md ("Environment facts") says it is install-time
   `meshConfig` and "not set on the gateway Service or Deployment". The two
   disagree. `question.md` avoids saying where it is set. The mesh-wide form
   is probably `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies`,
   not `meshConfig.gatewayTopology`. Check this before changing either side.
4. **OUTPUT reuse.** I treated the old guide outputs as real. I could not tell
   whether pod names and similar values came from a live run.
5. **Grading machine needs.** `python3` (010, 020 validators), `openssl` (040
   bootstrap and solution) and outbound internet (030 tokens, 060 Gateway API
   CRDs from github.com) must be on the machine that runs astrona.
6. **No `<!-- astrona:playground:renew -->` in lab docs.** The ATS014 lab
   `solution.md` files do not have it, so I did not add it.
