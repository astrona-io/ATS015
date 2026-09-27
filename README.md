# ATS015 — Securing Workloads (Istio Certified Associate)

Course material for the **Securing Workloads** domain of the Istio Certified Associate (ICA) exam, which is **25% of the exam**.

Everything lives under `sections/`. Each section is a set of modules, and each
module is:

- a short **landing page** (`course.md`) plus ordered **deep-dive parts**
  (`course-0N-*.md`) that take the subject down to the mechanism, woven with
  hands-on "Try it" checkpoints;
- an ungraded **playground** — a throwaway cluster to explore on;
- a graded **lab** under `labs/lab-01/`, written exam-style with a task, a case
  study, a full walkthrough and behavioural grading.

Each section also ends with a **capstone lab** combining its modules.

Read a module's landing page for the map, work through its parts in order, run
the playground alongside them, then solve the lab without looking at the
walkthrough — and the section's capstone once every module is done.

[`astrona.yaml`](astrona.yaml) is the manifest: every section, module, reading,
playground, lab and capstone in the order they are meant to be taken.

Everything targets **Istio 1.30.5** on a single-node `kind` cluster.

---

## Sections

| Section | Title | Modules | Curriculum item |
| --- | --- | --- | --- |
| [010](sections/section-010) | Workload Identity And Mutual TLS | 3 | Configuring Authentication (mTLS, JWT) |
| [020](sections/section-020) | Authorization Policy Fundamentals | 2 | Configuring Authorization |
| [030](sections/section-030) | End-User Authentication With JWT | 2 | Configuring Authentication (mTLS, JWT) / Configuring Authorization |
| [040](sections/section-040) | Securing Edge Traffic With TLS | 3 | Securing Edge Traffic with TLS |
| [050](sections/section-050) | Authorization At The Edge | 1 | Configuring Authorization |
| [060](sections/section-060) | Authorization In Ambient Mode | 1 | Configuring Authorization |

The sections are ordered so that each one only needs what came before it. Identity comes first because every `principals` value in the course is that string; `PeerAuthentication` follows, because identity-based authorization cannot work without verified identity; the edge sections come after the in-mesh ones; and ambient is last because it reuses all of it.

The exam's three curriculum items are not contiguous in this ordering — authorization is split across sections 020, 030, 050 and 060 — because teaching order and exam taxonomy are different things. The table above maps each section back to its item.

---

## Modules

Each reader below is a landing page; its deep-dive parts are linked from it and from the section README.

| Module | Reader | Parts | Graded lab |
| --- | --- | --- | --- |
| 010-01 | [Inspect Workload Identity And Certificates](sections/section-010/module-01/course.md) | 3 | [`labs/lab-01`](sections/section-010/module-01/labs/lab-01/) |
| 010-02 | [Enforce mTLS With PeerAuthentication At Three Scopes](sections/section-010/module-02/course.md) | 3 | [`labs/lab-01`](sections/section-010/module-02/labs/lab-01/) |
| 010-03 | [Migrate A Namespace From PERMISSIVE To STRICT mTLS](sections/section-010/module-03/course.md) | 3 | [`labs/lab-01`](sections/section-010/module-03/labs/lab-01/) |
| 020-01 | [Authorize HTTP Traffic Between Workloads](sections/section-020/module-01/course.md) | 4 | [`labs/lab-01`](sections/section-020/module-01/labs/lab-01/) |
| 020-02 | [DENY Policies And Evaluation Order](sections/section-020/module-02/course.md) | 3 | [`labs/lab-01`](sections/section-020/module-02/labs/lab-01/) |
| 030-01 | [Authenticate End Users With JWT](sections/section-030/module-01/course.md) | 3 | [`labs/lab-01`](sections/section-030/module-01/labs/lab-01/) |
| 030-02 | [Authorize On JWT Claims](sections/section-030/module-02/course.md) | 3 | [`labs/lab-01`](sections/section-030/module-02/labs/lab-01/) |
| 040-01 | [Terminate TLS At The Ingress Gateway](sections/section-040/module-01/course.md) | 3 | [`labs/lab-01`](sections/section-040/module-01/labs/lab-01/) |
| 040-02 | [Require Client Certificates At The Edge](sections/section-040/module-02/course.md) | 3 | [`labs/lab-01`](sections/section-040/module-02/labs/lab-01/) |
| 040-03 | [TLS Passthrough Instead Of Termination](sections/section-040/module-03/course.md) | 3 | [`labs/lab-01`](sections/section-040/module-03/labs/lab-01/) |
| 050-01 | [Authorize By Source IP At The Ingress Gateway](sections/section-050/module-01/course.md) | 3 | [`labs/lab-01`](sections/section-050/module-01/labs/lab-01/) |
| 060-01 | [Authorization In Ambient Mode, L4 And L7](sections/section-060/module-01/course.md) | 4 | [`labs/lab-01`](sections/section-060/module-01/labs/lab-01/) |

---

## Running a playground

Every module has one. It is a **kind** cluster with Istio 1.30.5 installed and the module's starting workloads applied — plus, where a module needs one, a precondition such as a `STRICT` `PeerAuthentication` or a `RequestAuthentication`. The objects each module is *about* are deliberately absent, because writing them is the point.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/playground
astrona destroy ats-015-playground-010-01
```

Playgrounds are **ungraded**. There is no task, no `astrona submit`, no pass/fail. Each one's `docs/overview.md` lists what is in the box and a set of things worth trying — including deliberate mistakes, which are often the fastest way to learn a failure signature.

`astrona destroy` takes the environment **name** (`metadata.name` in the playground's `config.yaml`), not the config path. The name is printed in each module's playground callout.

### Three environment notes

- **No load balancer.** On `kind`, a gateway Service's `EXTERNAL-IP` stays `<pending>`. Sections 040 and 050 use `kubectl port-forward` instead; this is expected, not a fault. It also affects what source address a gateway sees, which section 050 makes use of deliberately.
- **Outbound internet.** Section 030 uses Istio's published demo JWTs and the matching JWKS endpoint on `raw.githubusercontent.com`. Without outbound access you will see key-fetch failures rather than mesh behaviour.
- **Section 060 is ambient.** It is the only playground installed with the `ambient` profile, so it has **no sidecars**. Commands from earlier sections that target `-c istio-proxy`, or `istioctl proxy-config` on an application pod, have no counterpart there — use `istioctl ztunnel-config`.

---

## Labs and capstones

Every module has a graded lab; every section has a capstone that combines its
modules. Both are ordinary Astrona labs: they provision a `kind` cluster with
Istio 1.30.5, apply a starting state, and grade the end state with declarative
checks plus a behavioural script.

| Section | Capstone |
| --- | --- |
| [010](sections/section-010/capstone/labs/lab-01/) | Workload Identity And Mutual TLS Capstone |
| [020](sections/section-020/capstone/labs/lab-01/) | Authorization Policy Capstone |
| [030](sections/section-030/capstone/labs/lab-01/) | End-User Authentication Capstone |
| [040](sections/section-040/capstone/labs/lab-01/) | Edge TLS Capstone |
| [050](sections/section-050/capstone/labs/lab-01/) | Edge Authorization Capstone |
| [060](sections/section-060/capstone/labs/lab-01/) | Ambient Authorization Capstone |

Each lab folder holds:

| Path | Purpose |
| --- | --- |
| `docs/prerequisites.md` | What to know and have installed first |
| `docs/exam-question.md` | The formal, self-contained task |
| `docs/case-study.md` | The same task as a scenario, with hints instead of an answer |
| `docs/step-by-step-guide.md` | Full walkthrough, including the answer |
| `manifests/` | Starting state applied at bootstrap |
| `bootstrap/setup.sh` | Istio install and pre-work — never the graded objects |
| `solution/` | Reference end state, applied by `astrona test` in CI |
| `validate.sh` | Behavioural grading |

Run one, solve it, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c .
astrona destroy ats-015-lab-010-01
```

Authors and CI can prove a lab is solvable with
`astrona test -c . --junit-xml=report.xml`, which bootstraps it, applies
`solution/`, submits, and tears down.
