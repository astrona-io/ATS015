# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Plain English

Write the text in Plain English for a general adult audience (18+) without a
university degree. The content must be highly accessible and easy to
understand for non-technical readers, without feeling childish.

Strict guidelines:

1. Target a Flesch-Kincaid Grade Level of 8 or 9 (equivalent to a standard
   newspaper article).
2. Avoid all technical jargon, acronyms, and corporate buzzwords. If a
   technical term is necessary, explain it immediately using an everyday
   analogy.
3. Keep sentences conversational and direct. Split long sentences into two.
4. Use short paragraphs (max 3-4 sentences per paragraph) and clear
   subheadings to make the text scannable.
5. Use the active voice (e.g., "We did this" instead of "This was done by us").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page and a few
  deep-dive parts. The landing page is a map: goals, what to know first, the
  order of the parts, where it fits. The real teaching goes in the parts. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module, the wrap-up links and `astrona.yaml`.
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
  need the `scout` `DestinationRule` applied"). The wrap-up page is the one
  exception: it recaps each part and links to it.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Keep them, but explain
  each one in plain words, with an everyday analogy, the first time it appears
  in a file. Spell out acronyms on first use, with a short plain meaning.
- **Analogies come from space, and the reader is an astronaut.** When a term
  needs an everyday picture, use space: spaceships, planets, solar systems,
  space stations, mission control, signals, docking, star charts, airlocks,
  even the Death Star. Talk to the reader as an astronaut (for example "your
  first mission", "astronaut, check your flight log"), but not in every
  sentence. Requests are **signals** that ships send to each other. Use one
  analogy per hard idea, keep it short, and keep it the same everywhere (if
  the repository has an analogy glossary, use it). The analogy helps the reader; it
  never replaces the real term, and it never changes code or output.
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
- **Keep the page furniture the same.** Hands-on steps are normal page
  content, not boxes: a short `###` subsection (for example "See it in your
  playground") with one sentence saying what to do, the command, the real
  output, and one or two sentences saying what it shows. A `> [!TIP]` box is
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
  `astrona destroy <lab name>` plus `astrona start <playground name>`. The
  wrap-up lists the missions and ends with cleaning up the playground
  (`astrona list`, `astrona destroy <playground name>`).
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), wrap-up pages or pages without commands.
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

### Space analogy glossary

Use these pictures for these terms, in every course page, lab and playground.
Keep them consistent so the astronaut builds one picture of the universe.
Most pages written before these rules have no space analogies yet; add them
when you rework a page, using this table.

**The universe**

| Term | Space picture |
| --- | --- |
| The learner | An astronaut (a cadet on their first missions) |
| Kubernetes cluster | A solar system |
| Namespace | A planet in that solar system |
| Pod | A spaceship |
| Container | A module inside the ship (the app is the crew) |
| Kubernetes Service | A beacon: one call sign that a whole group of ships answers to |
| Service account | The ship's registration papers |
| Request / response | A signal sent out, and the reply signal |
| Port | A radio channel |
| Service mesh | The fleet's shared signal network |
| `kind` cluster on your laptop | A training solar system in the simulator |

**The mesh**

| Term | Space picture |
| --- | --- |
| Sidecar proxy (Envoy) | The ship's communications officer: every signal in or out goes through them |
| Sidecar injection | Putting a communications officer on board when the ship launches (ships already flying do not get one) |
| `istiod` (control plane) | Mission control: it sends every communications officer their orders and issues ID badges |
| xDS push | Mission control radioing new orders to every ship in flight, no landing needed (no restart) |

**Identity and authentication**

| Term | Space picture |
| --- | --- |
| Workload identity (SPIFFE ID) | The ship's ID badge, printed from its registration papers |
| Certificate / SAN | The badge card itself; the SAN is the name printed on it |
| Certificate authority (istiod CA) | The badge office at mission control |
| Root certificate / trust domain | The fleet's official seal; badges with another seal are not trusted |
| Certificate rotation | Mission control swapping each badge for a fresh one before it expires |
| mTLS | A secret handshake: both ships show their badges before they talk |
| `PeerAuthentication` | The rule on a ship's airlock: who must do the handshake before docking |
| `STRICT` / `PERMISSIVE` / `DISABLE` | Handshake required / handshake welcome but not required / no handshake |
| Mesh, namespace and workload scope | A rule for the whole fleet, for one planet, or for one ship; the closest rule wins |
| Plain-text caller outside the mesh | A ship with no badge and no communications officer |
| JWT (JSON Web Token) | A signed boarding pass an astronaut carries with every signal |
| `RequestAuthentication` | The pass checker: it checks any pass shown, but does not demand one |
| JWKS (key set) | The list of official stamps the pass checker compares passes against |
| Claims | The lines printed on the boarding pass (who, which crew, which clearance) |

**Authorization**

| Term | Space picture |
| --- | --- |
| `AuthorizationPolicy` | The guard's list at the airlock: who may come aboard and what they may do |
| `ALLOW` / `DENY` / `CUSTOM` / `AUDIT` | Guest list / banned list / ask an outside guard / write it in the log only |
| Default-deny (`spec: {}` or first `ALLOW`) | Once a guest list exists, anyone not on it stays outside the airlock |
| `from`, `to`, `when` | Who sends the signal, which door and channel it asks for, extra conditions |
| `principals` | The name on the ship's ID badge |
| `requestPrincipals` | The name on the astronaut's boarding pass |
| `RBAC: access denied` (403) | The guard turned the signal away at the airlock |
| Evaluation order (CUSTOM, DENY, ALLOW) | The guard checks the banned list before the guest list |

**The borders of the solar system**

| Term | Space picture |
| --- | --- |
| Ingress gateway | The spaceport arrival gate: the one door signals from outside the solar system come through |
| TLS termination (`SIMPLE`) | The arrival gate opens the sealed signal, checks it, then sends it on inside |
| Mutual TLS at the gate (`MUTUAL`) | The arrival gate also demands a badge from the visitor's ship |
| TLS passthrough (`PASSTHROUGH`) | The gate forwards the sealed signal unopened; only the destination ship can open it |
| SNI (Server Name Indication) | The address written on the outside of the sealed envelope |
| Gateway credential (Kubernetes Secret) | The gate's own badge and key, kept in the gate's safe |
| Source IP, `remoteIpBlocks`, `numTrustedProxies` | The return address on a signal, and how many relay stations to trust when reading it |

**Ambient mode (section 060)**

| Term | Space picture |
| --- | --- |
| Ambient mode | Ships fly without their own communications officer; shared relay towers do the job instead |
| ztunnel | A shared relay tower, one per node (launch pad), for every ship docked there: it does the handshake and checks badges, but cannot read the signal's contents |
| HBONE | The sealed tunnel the relay towers use between them |
| Waypoint | A checkpoint station you build only where someone must read the signal's contents (L7 rules) |
| L4 rule vs L7 rule | Checking the envelope (who, which channel) vs reading the letter (path, method, headers) |

### The playground fleet: the Starfleet

The playgrounds and course pages run the Istio Bookinfo sample with **space
names**, the same fleet as in the other Istio courses. The images are the
official Bookinfo images; only the Kubernetes names change. Use these names
everywhere (commands, YAML, prose). Never call it a "book review" app.

| Space name (Kubernetes name) | Was in Bookinfo / new-data | Service account | Role |
| --- | --- | --- | --- |
| `starfleet` (namespace) | `bookinfo` | | The planet the fleet lives on (sidecar injection on) |
| `bridge` | `productpage` | `starfleet-bridge` | The flagship command deck: the page astronauts see; it signals the other ships |
| `cargo` | `details` | `starfleet-cargo` | The supply ship: answers with facts about an item |
| `scout` v1/v2/v3 | `reviews` | `starfleet-scout` | Three ship classes of one scout: v1 no stars, v2 black stars, v3 red stars |
| `navcom` | `ratings` | `starfleet-navcom` | The navigation computer the v2 and v3 scouts ask for the star rating |
| `shuttle` | `curl` | `shuttle` | Your test client inside the mesh: every test signal is sent from here |
| `probe` v1/v2 | `httpbin` | `probe` | The echo probe: sends back exactly what it receives (Service port `8000`, container port `8080`) |
| `fortio` | `fortio` | `default` | The load generator; here mostly a second caller with another identity |
| `outpost` (namespace) | `legacy` | | A planet with sidecar injection **off**, on purpose |
| `drifter` (in `outpost`) | `legacy/curl` | `default` | An old ship with no communications officer and no ID badge: it can only send plain text |
| `jason` | `jason` | | A fellow astronaut; logged in on the bridge, their signals carry `end-user: jason` |

Each ship's SPIFFE identity follows from the table, for example
`spiffe://cluster.local/ns/starfleet/sa/shuttle` or
`spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge`. The drifter has
no identity at all.

Built into the images and **unchanged**: the URL paths `/productpage`,
`/details/0`, `/reviews/0`, `/ratings/0`, and the probe's `/headers`,
`/get`, `/status/...`, `/ip`. So a signal to the probe is
`http://probe:8000/headers`. The fleet manifests live in each playground's
`bootstrap/manifests/` (`starfleet.yaml`, `shuttle.yaml`, `probe.yaml`,
`outpost.yaml`, `fortio.yaml`, `access-logs.yaml`, `namespace.yaml`), copied
from the same files in the ATS014 course so both courses show one fleet.

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
| Module reading: landing page, deep-dive parts, wrap-up | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
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
wrap-up page comes last. The section capstone closes the section. Playgrounds
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
