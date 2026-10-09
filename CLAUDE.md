# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Mission Briefing's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS015 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** pass the **Securing Workloads** domain of the **Istio
  Certified Associate (ICA)** exam. It is 25% of the exam.
- **What the exam really tests:** writing Istio security configuration by
  hand, on a live cluster, under time pressure, and proving it works. So the
  student must *do* things (turn on mTLS, allow and deny callers, require a
  token, put TLS on the gateway), not just recognise words. Every
  explanation should lead to something they can run, and every policy should
  be proved with a real request that is allowed and one that is denied.
- **The three exam topics (curriculum items):** configuring authentication
  (mTLS and JWT), configuring authorization, and securing edge traffic with
  TLS. The course order is not the exam order: authorization is spread over
  sections 020, 030, 050 and 060. The README table maps each section to its
  exam topic.
- **The sections:**

  | Section | Title | Exam topic |
  | --- | --- | --- |
  | 010 | Workload Identity And Mutual TLS | Authentication (mTLS, JWT) |
  | 020 | Authorization Policy Fundamentals | Authorization |
  | 030 | End-User Authentication With JWT | Authentication / Authorization |
  | 040 | Securing Edge Traffic With TLS | Edge TLS |
  | 050 | Authorization At The Edge | Authorization |
  | 060 | Authorization In Ambient Mode | Authorization |

- **The version:** everything is built and checked on **Istio 1.30.5** on a
  single-node `kind` cluster. Playgrounds and most labs install it with
  Helm (see "Environment facts" below); section 060 is the only one
  installed in ambient mode, so it has no sidecars. Do not teach
  fields or behaviour from other versions without saying so.
- **The main sources:** the Istio security concepts page,
  <https://istio.io/latest/docs/concepts/security/>, and the API reference
  for each security object. Check every page against them.

### Terms, not metaphors

Explanations use Istio's and Kubernetes' own words. Define each one in plain
technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Sidecar proxy (Envoy) | A proxy container Istio adds to each pod; all inbound and outbound traffic of the pod passes through it |
| `istiod` | Istio's control plane; it sends configuration and certificates to every proxy |
| xDS | The protocol `istiod` uses to push configuration to proxies while they run |
| Workload identity (SPIFFE ID) | The name in a workload's certificate, built from its namespace and service account: `spiffe://cluster.local/ns/<namespace>/sa/<service account>` |
| mTLS | Mutual TLS: both sides present a certificate, so the connection is encrypted and both identities are verified |
| `PeerAuthentication` | Sets whether a workload accepts plain text, mTLS or both on inbound connections (`PERMISSIVE`, `STRICT`, `DISABLE`) |
| `RequestAuthentication` | Validates a JWT if the request carries one; it does not require a token |
| JWT | JSON Web Token: a signed token that carries claims about the end user |
| `AuthorizationPolicy` | Allows or denies requests to a workload, by source, operation and conditions |
| Ingress gateway | An Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster |
| TLS termination / passthrough | The gateway decrypts the connection / forwards it encrypted, routing on SNI only |
| ztunnel | The per-node proxy in ambient mode; it handles mTLS and L4 authorization, but not HTTP |
| Waypoint | An Envoy proxy you deploy in ambient mode to enforce L7 (HTTP) policy |

Older pages still use space metaphors (communications officer, signal,
badge, guest list, airlock). Replace them with the real terms when you touch
a page.

### The example workloads: the Starfleet

The playgrounds and course pages run the Istio Bookinfo sample with **space
names**, the same workloads as in the other Istio courses. The images are the
official Bookinfo images; only the Kubernetes names change. Use these names in
commands, YAML and example text. The names are the only space element: describe
what each workload does in technical terms. Never call it a "book review" app.

| Kubernetes name | Was in Bookinfo / new-data | Service account | What it is |
| --- | --- | --- | --- |
| `starfleet` (namespace) | `bookinfo` | | Namespace for the sample app, sidecar injection on |
| `bridge` | `productpage` | `starfleet-bridge` | Web frontend (`/productpage`); calls `cargo` and `scout` |
| `cargo` | `details` | `starfleet-cargo` | Backend that returns item details |
| `scout` v1/v2/v3 | `reviews` | `starfleet-scout` | Backend in three versions: v1 no stars, v2 black stars, v3 red stars |
| `navcom` | `ratings` | `starfleet-navcom` | Backend that `scout` v2 and v3 call for the star rating |
| `shuttle` | `curl` | `shuttle` | Test client pod in the mesh; test requests are sent from here |
| `probe` v1/v2 | `httpbin` | `probe` | HTTP echo server (go-httpbin); Service port `8000`, container port `8080` |
| `fortio` | `fortio` | `default` | Load generator; mostly used as a second client with another identity |
| `outpost` (namespace) | `legacy` | | Namespace with sidecar injection **off**, on purpose |
| `drifter` (in `outpost`) | `legacy/curl` | `default` | Client pod with no sidecar: no certificate, sends plain text only |
| `jason` | `jason` | | Example end user; after login on the bridge, its requests carry `end-user: jason` |

Each workload's SPIFFE identity follows from the table, for example
`spiffe://cluster.local/ns/starfleet/sa/shuttle` or
`spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge`. The drifter has
no identity at all.

Built into the images and **unchanged**: the URL paths `/productpage`,
`/details/0`, `/reviews/0`, `/ratings/0`, and the probe's `/headers`,
`/get`, `/status/...`, `/ip`. So a request to the probe goes to
`http://probe:8000/headers`. The fleet manifests live in each playground's
`bootstrap/manifests/` (`starfleet.yaml`, `shuttle.yaml`, `probe.yaml`,
`outpost.yaml`, `fortio.yaml`, `access-logs.yaml`, `namespace.yaml`), copied
from the same files in the ATS014 course so both courses use the same workloads.

**Graded labs keep their own small apps for now.** The older labs and
capstones run `booking-service` (service account `booking-sa`),
`notification-service` and a `tester` client on port `8084`, each in its own
namespace (`identity-demo`, `mtls-demo`, `authz-demo` and so on). Their
`question.md` describes that app, so the learner is never confused. New labs
use the Starfleet.

### Environment facts the text must respect

- **Playgrounds install Istio with Helm** (`istio-base` and `istiod`, plus the
  `istio-ingress` gateway chart where a module needs a gateway), the same way
  as ATS014. Section 060 installs the ambient charts (`istio-cni`, `ztunnel`).
  Labs install the same way; a few older labs still use
  `istioctl install --set profile=demo`, and either is fine while the lab
  passes `astrona test`.
- **No load balancer on `kind`.** A gateway Service's `EXTERNAL-IP` stays
  `<pending>`. Playgrounds reach the gateway through the `portForwards` in
  `config.yaml` (`127.0.0.1:8080` and `127.0.0.1:8443`); labs use
  `kubectl port-forward`. This also changes the source address the gateway
  sees, which section 050 uses on purpose.
- **Outbound internet.** Section 030 uses Istio's published demo tokens
  (`demo.jwt`, `groups-scope.jwt`) and their `jwks.json` from
  `raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/`.
  The egress TLS module calls `httpbin.org`. These addresses are used in
  commands, so they are allowed on the page.
- **Ambient has no sidecars.** In section 060, never use `-c istio-proxy`
  or `istioctl proxy-config` on an application pod; use
  `istioctl ztunnel-config` and the waypoint's own proxy.
- **`numTrustedProxies` is proxy configuration, not a MeshConfig field.**
  It must reach the gateway's own proxy: the
  `proxy.istio.io/config: '{"gatewayTopology":{"numTrustedProxies":1}}'`
  annotation on the gateway pod template, or the mesh-wide default
  `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies`.
  `meshConfig.gatewayTopology.numTrustedProxies` is accepted and silently
  ignored. Proof: `xffNumTrustedHops` appears in the gateway's listener dump.
  Changing it restarts the gateway.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections table, how to run things | `README.md` |
| Mission Briefing: course intro, setup, how the course is made, maintainers, how to report mistakes (first in `astrona.yaml`) | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, summary | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-0N/` (`question.md`, `solution.md`, `bootstrap/`, `solution/apply.sh`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`docs/overview.md` says what is in the box, `docs/practice.md` has exam-style tasks, `examples/` the authors' reference YAML) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |
| Merge notes for the new-data import (temporary) | `.astrona/merge-plan.md` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` has `question: "question.md"` and `solution: "solution.md"` |
| `README.md` | Short intro with `estimated_duration` front matter and the run, submit and destroy commands |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/01-install-istio.sh`, `02-seed-workloads.sh`, `bootstrap/manifests/` | Istio install and starting state, never the graded objects |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `validation/validate-completed.sh` | Behavioural grading (sends real traffic) |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has one entry per section under `modules:` (`module-intro`,
`module-010`, `module-020` and so on). Each section's `content` lists, in
order: the section `README.md`, then for each module its landing page, its
parts, and right after the part a lab tests, a `Question` reading
(`labs/lab-0N/question.md`) followed by the `type: lab` entry; the module's
summary page comes last. The section capstone closes the section. Playgrounds
are not listed: the landing page's `<!-- astrona:playground -->` marker shows
them.

Every `type: lab` entry (module labs and capstones) carries these fields, in
this order:

```yaml
      - type: reading
        title: Question
        path: sections/section-010/module-01/labs/lab-01/question.md
      - type: lab
        title: "Prove A Workload Identity And Authorize On It Lab"
        path: sections/section-010/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 20m
        topic: identity
        task_kind: build
        tags: [spiffe, certificates, principals, authorizationpolicy, proxy-config]
        learning_goals:
          - Read a workload's SPIFFE identity from its live certificate
          - Write an AuthorizationPolicy that allows exactly that principal
        resources:
          - name: "Istio security concepts"
            url: https://istio.io/latest/docs/concepts/security/
```

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`, `45m`.
- `topic`: exactly one of `identity`, `mtls`, `authorization`, `jwt`,
  `edge-tls`, `egress-tls`, `edge-authorization`, `ambient`.
- `task_kind`: exactly one of `build` (write the configuration from
  scratch), `troubleshooting` (find and fix what is broken) or `migration`
  (move a working setup to another mode or layout, for example `PERMISSIVE`
  to `STRICT`). The platform filters labs by it, so it is a field of its
  own, never a tag.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb, saying
  what the learner proves in this lab.
- `resources`: 1 to 4 documentation pages, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed: the
  platform shows them as optional further reading next to the lab.

**Tag list** (lower case, hyphens, never synonyms):

- Istio objects: `peerauthentication`, `requestauthentication`,
  `authorizationpolicy`, `gateway`, `virtualservice`, `destinationrule`,
  `serviceentry`, `gateway-api`, `waypoint`
- Identity and mTLS: `spiffe`, `certificates`, `trust-domain`,
  `cert-rotation`, `mtls-strict`, `mtls-permissive`, `mtls-scopes`,
  `port-level-mtls`, `sidecar-injection`
- Authorization: `default-deny`, `allow-nothing`, `deny-policy`,
  `audit-policy`, `custom-policy`, `principals`, `namespaces`, `ip-blocks`,
  `remote-ip-blocks`, `paths`, `methods`, `when-conditions`,
  `evaluation-order`
- End users: `jwt`, `jwks`, `request-principals`, `jwt-claims`,
  `jwt-audiences`, `forward-original-token`
- Edge: `ingress-gateway`, `tls-termination`, `mutual-tls-gateway`,
  `tls-passthrough`, `sni`, `https-redirect`, `credential-name`,
  `num-trusted-proxies`, `tls-origination`, `external-services`
- Ambient: `ambient`, `ztunnel`, `hbone`, `l4-policy`, `l7-policy`,
  `target-refs`
- Failure signatures: `rbac-403`, `jwt-401`, `connection-reset`,
  `tls-handshake-failure`, `503-uf`, `503-uc`, `ist0101`
- Tools: `proxy-config`, `proxy-status`, `istioctl-analyze`,
  `istioctl-x-describe`, `ztunnel-config`, `openssl`, `access-log`,
  `debug-logging`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/playground
astrona destroy ats-015-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-015-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-015-playground-<section>-<module>`. The first
labs are `ats-015-lab-<section>-<module>`; keep those names. A new lab takes
`ats-015-lab-<section>-<module>-<lab>`, for example `ats-015-lab-040-04-01`,
so two labs never share a name. Lab
bootstrap scripts do not pin a kube context: astrona sets `KUBECONFIG` for
the lab, and `astrona test` runs on a cluster with a different name. Every
lab must pass `astrona validate` and `astrona test`.

Graders check **behaviour** (send real traffic and check that the right
callers get through and the wrong ones get `403` or a reset), not just that
an object exists. A lab's `question.md` and `solution.md` must match what
its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
Never touch clusters you did not create (for example `istio-doc`).

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Concepts (the course spine):**
  <https://istio.io/latest/docs/concepts/security/>
- **API reference, one page per object:**
  [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/),
  [RequestAuthentication](https://istio.io/latest/docs/reference/config/security/request_authentication/),
  [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/),
  [Authorization conditions](https://istio.io/latest/docs/reference/config/security/conditions/),
  [Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/),
  [JWT](https://istio.io/latest/docs/reference/config/security/jwt/)
- **Hands-on tasks:** <https://istio.io/latest/docs/tasks/security/>, for
  example mutual TLS migration, authentication policy, HTTP and TCP
  authorization, JWT authorization, explicit deny, ingress authorization
  (source IP), and <https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/>
  plus the ingress SNI passthrough task for edge TLS.
- **Ambient:** <https://istio.io/latest/docs/ambient/usage/l4-policy/> and
  <https://istio.io/latest/docs/ambient/usage/l7-features/>, plus the
  waypoint page.
- **Debugging and proof:**
  [proxy-config and proxy-status](https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/),
  [istioctl analyze messages](https://istio.io/latest/docs/reference/config/analysis/),
  [security problems](https://istio.io/latest/docs/ops/common-problems/security-issues/),
  [network topology and `numTrustedProxies`](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
- **The exam itself:** the ICA page on the Linux Foundation / CNCF training
  site lists the official curriculum. The domain weight (25%) and topic list
  above come from this repository's README and `astrona.yaml` and have not
  been re-checked against it.

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository: planning
(`domain-plan`), creating the tree (`domain-scaffold`), building modules
(`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds (`lab`),
lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
