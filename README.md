# ATS015: Securing Workloads (Istio Certified Associate)

This course trains you for the **Securing Workloads** domain of the Istio Certified Associate (ICA) exam. That domain is **25% of the exam**.

Everything is built and checked on **Istio 1.30.5**, running on a single-node `kind` cluster on your own machine.

Every module here is about one question: which workload may send a request to which other workload? Istio's control plane, `istiod`, gives each pod a certificate that holds its workload identity. Pods prove that identity to each other with mutual TLS (mTLS), where both sides of a connection present a certificate. An `AuthorizationPolicy` then reads the caller's identity and allows or denies the request. You will learn to set up each of these by hand, and to prove they work with real requests.

The repository has four layers:

| Layer | Path | What it is |
| --- | --- | --- |
| **Outline** | `astrona.yaml` | The course outline the platform reads: every reading page and lab, in order |
| **Reading** | `sections/section-0N0/module-0M/` | A short landing page, ordered chapters that teach one idea each with hands-on steps in the text, and a summary |
| **Practice** | `.../module-0M/labs/lab-0N/` and `.../module-0M/playground/` | Graded labs, each placed right after the part it practises, and one ungraded sandbox per module |
| **Integration** | `sections/section-0N0/capstone/labs/lab-01/` | One graded capstone per section that combines all of its modules |

The way through each module is simple. Read its parts with its playground open alongside. When a part ends with **Your mission**, pause the playground and take that lab without looking at the solution. The module ends with a summary of what you learned, and the playground is removed. Finish each section with its capstone.

---

## Start Here

New to the course? Read the **[Mission Briefing](sections/intro/README.md)** first. It explains how the course is laid out, how to get your machine ready, how the content is made, who maintains it, and how to report a mistake.

---

## What The Domain Covers

The exam lists three topics for this domain. The course teaches them in a different order, because each section only needs what came before it. Authorization is spread over four sections, so the table below maps each section to its exam topic.

| Section | Title | Modules | Exam topic |
| --- | --- | --- | --- |
| [010](sections/section-010/README.md) | Workload Identity And Mutual TLS | 3 | Configuring Authentication (mTLS, JWT) |
| [020](sections/section-020/README.md) | Authorization Policy Fundamentals | 2 | Configuring Authorization |
| [030](sections/section-030/README.md) | End-User Authentication With JWT | 2 | Configuring Authentication (mTLS, JWT) and Configuring Authorization |
| [040](sections/section-040/README.md) | Securing Edge Traffic With TLS | 4 | Securing Edge Traffic with TLS |
| [050](sections/section-050/README.md) | Authorization At The Edge | 1 | Configuring Authorization |
| [060](sections/section-060/README.md) | Authorization In Ambient Mode | 1 | Configuring Authorization |

**13 modules, 61 parts, 24 graded labs, 6 capstones and 13 playgrounds.**

Here is why the order works:

- **Identity comes first.** Every `principals` value in the course is a workload's identity string, so you learn to read it before you use it.
- **`PeerAuthentication` comes next.** Rules based on identity only work once mTLS proves that identity.
- **The edge comes after the mesh.** Gateways, TLS and address rules build on what you already know inside the mesh.
- **Ambient mode comes last.** It reuses all of it, without sidecars.

[`astrona.yaml`](astrona.yaml) lists 157 entries: the briefing and the six sections, in the order you should work through them. The lab walkthroughs (`solution.md`) are left out of it on purpose, so you try each lab before you see the answer.

---

## Modules

Each module has a landing page, ordered chapters and a summary. The landing page describes the chapters in order. Each section overview lists every chapter, with the labs that follow it. The "Parts" count leaves out the summary page.

| Module | Reader | Parts | Graded labs (environment name) |
| --- | --- | --- | --- |
| 010-01 | [Inspect Workload Identity And Certificates](sections/section-010/module-01/course.md) | 3 | [Prove A Workload Identity And Authorize On It](sections/section-010/module-01/labs/lab-01/README.md) (`ats-015-lab-010-01`) |
| 010-02 | [Enforce mTLS With PeerAuthentication At Three Scopes](sections/section-010/module-02/course.md) | 6 | [Enforce mTLS At Three Scopes](sections/section-010/module-02/labs/lab-01/README.md) (`ats-015-lab-010-02`), [Open One Port With portLevelMtls](sections/section-010/module-02/labs/lab-02/README.md) (`ats-015-lab-010-02-02`), [Fix A DestinationRule That Breaks mTLS](sections/section-010/module-02/labs/lab-03/README.md) (`ats-015-lab-010-02-03`) |
| 010-03 | [Migrate A Namespace From PERMISSIVE To STRICT mTLS](sections/section-010/module-03/course.md) | 4 | [Migrate A Namespace To STRICT mTLS](sections/section-010/module-03/labs/lab-01/README.md) (`ats-015-lab-010-03`) |
| 020-01 | [Authorize HTTP Traffic Between Workloads](sections/section-020/module-01/course.md) | 6 | [Lock A Namespace Down With ALLOW Policies](sections/section-020/module-01/labs/lab-01/README.md) (`ats-015-lab-020-01`), [Repair Broken AuthorizationPolicies](sections/section-020/module-01/labs/lab-02/README.md) (`ats-015-lab-020-01-02`) |
| 020-02 | [DENY Policies And Evaluation Order](sections/section-020/module-02/course.md) | 6 | [Close A Path With DENY](sections/section-020/module-02/labs/lab-01/README.md) (`ats-015-lab-020-02`), [Make The Probe Read-Only](sections/section-020/module-02/labs/lab-02/README.md) (`ats-015-lab-020-02-02`) |
| 030-01 | [Authenticate End Users With JWT](sections/section-030/module-01/course.md) | 4 | [Require A Valid End-User Token](sections/section-030/module-01/labs/lab-01/README.md) (`ats-015-lab-030-01`), [Read A JWT From A Query Parameter](sections/section-030/module-01/labs/lab-02/README.md) (`ats-015-lab-030-01-02`) |
| 030-02 | [Authorize On JWT Claims](sections/section-030/module-02/course.md) | 4 | [Authorize On A JWT Claim](sections/section-030/module-02/labs/lab-01/README.md) (`ats-015-lab-030-02`), [Fix The Claim Rule](sections/section-030/module-02/labs/lab-02/README.md) (`ats-015-lab-030-02-02`) |
| 040-01 | [Terminate TLS At The Ingress Gateway](sections/section-040/module-01/course.md) | 4 | [Serve HTTPS At The Ingress Gateway](sections/section-040/module-01/labs/lab-01/README.md) (`ats-015-lab-040-01`), [Fix A Broken HTTPS Gateway](sections/section-040/module-01/labs/lab-02/README.md) (`ats-015-lab-040-01-02`) |
| 040-02 | [Require Client Certificates At The Edge](sections/section-040/module-02/course.md) | 4 | [Require Client Certificates At The Edge](sections/section-040/module-02/labs/lab-01/README.md) (`ats-015-lab-040-02`), [Fix The Trusted CA In A MUTUAL Gateway](sections/section-040/module-02/labs/lab-02/README.md) (`ats-015-lab-040-02-02`) |
| 040-03 | [TLS Passthrough Instead Of Termination](sections/section-040/module-03/course.md) | 5 | [Route An Encrypted Stream By SNI](sections/section-040/module-03/labs/lab-01/README.md) (`ats-015-lab-040-03`), [Fix A Passthrough Gateway That Routes Nothing](sections/section-040/module-03/labs/lab-02/README.md) (`ats-015-lab-040-03-02`) |
| 040-04 | [Originate TLS For External Services](sections/section-040/module-04/course.md) | 5 | [Originate TLS To An External Service](sections/section-040/module-04/labs/lab-01/README.md) (`ats-015-lab-040-04-01`) |
| 050-01 | [Authorize By Source IP At The Ingress Gateway](sections/section-050/module-01/course.md) | 5 | [Block A Client Range At The Gateway](sections/section-050/module-01/labs/lab-01/README.md) (`ats-015-lab-050-01`), [Open One Path To One Network](sections/section-050/module-01/labs/lab-02/README.md) (`ats-015-lab-050-01-02`) |
| 060-01 | [Authorization In Ambient Mode, L4 And L7](sections/section-060/module-01/course.md) | 5 | [Allow Callers By Identity With L4 Policy](sections/section-060/module-01/labs/lab-02/README.md) (`ats-015-lab-060-01-02`), [Enforce L4 And L7 Policy In Ambient Mode](sections/section-060/module-01/labs/lab-01/README.md) (`ats-015-lab-060-01`) |

In 060-01 the labs are listed in the order you take them: `lab-02` comes before `lab-01`.

Each section ends with one capstone:

| Section | Capstone | Environment name |
| --- | --- | --- |
| 010 | [Capstone: Turn On Mesh-Wide mTLS Without Stranding A Caller](sections/section-010/capstone/labs/lab-01/README.md) | `ats-015-capstone-010` |
| 020 | [Capstone: Deny By Default And Allow Two Calls](sections/section-020/capstone/labs/lab-01/README.md) | `ats-015-capstone-020` |
| 030 | [Capstone: Require A Token And Split Access By Claim](sections/section-030/capstone/labs/lab-01/README.md) | `ats-015-capstone-030` |
| 040 | [Capstone: Terminate And Pass Through TLS On One Gateway](sections/section-040/capstone/labs/lab-01/README.md) | `ats-015-capstone-040` |
| 050 | [Capstone: Block Client IP Ranges At The Ingress Gateway](sections/section-050/capstone/labs/lab-01/README.md) | `ats-015-capstone-050` |
| 060 | [Capstone: Enforce Request Rules Through A Waypoint](sections/section-060/capstone/labs/lab-01/README.md) | `ats-015-capstone-060` |

---

## Running A Playground

Every module has a playground: a `kind` cluster with Istio 1.30.5 and the module's starting workloads. The security objects the module is about are left out on purpose, because writing them is your task.

Every playground runs **the Starfleet**. This is the Bookinfo sample app from the Istio documentation, with space names: `bridge`, `cargo`, `scout` v1, v2 and v3, and `navcom`, in the namespace `starfleet`. Each module adds the extra workloads it needs, such as the `shuttle` test client, the `probe` echo service, `fortio`, or the `drifter` client in the namespace `outpost`, which has no sidecar.

The playgrounds install Istio with Helm: `istio-base` and `istiod`, plus the `istio-ingress` gateway chart where a module needs a gateway. Section 060 installs the ambient charts (`istio-cni` and `ztunnel`) instead of sidecars. You still need `istioctl` on your own machine to inspect things.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/playground
astrona destroy ats-015-playground-010-01
```

Playgrounds are **ungraded**. There is no task, no `astrona submit` and no pass or fail, so break things as often as you like. Each playground's `docs/overview.md` says what is in the box, and its `docs/practice.md` has exam-style tasks to try.

`astrona destroy` takes the environment **name**, not the folder path. The name is `metadata.name` in the playground's `config.yaml`, and it always follows the form `ats-015-playground-<section>-<module>`.

---

## Running A Lab Or Capstone

Labs are **graded** against the live state of your cluster.

```bash
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-015-lab-010-01
```

A capstone works the same way. For example, `astrona destroy ats-015-capstone-010` removes the first capstone.

Each lab folder holds:

| Path | What it is for |
| --- | --- |
| `config.yaml` | The lab definition. `metadata.name` is the environment name; `metadata.docs` names `question.md` and `solution.md` |
| `README.md` | A short intro with the run, submit and destroy commands |
| `question.md` | The exam-style task |
| `solution.md` | A step-by-step walkthrough with real output |
| `bootstrap/01-install-istio.sh`, `bootstrap/02-seed-workloads.sh`, `bootstrap/manifests/` | The Istio install and the starting state. Never the objects that get graded |
| `solution/apply.sh` | The reference end state. Only `astrona test` applies it |
| `validation/validate-completed.sh` | The grader. It sends real requests and checks that the right callers get through and the wrong ones are turned away |

Most labs run the Starfleet and install Istio with Helm. A few older labs and the capstones still run their own small app (for example `notification-service`) and install Istio with `istioctl install --set profile=demo -y`. Their `question.md` describes that app.

### Checking A Lab As An Author

Authors can run a local, uncommitted copy, and prove a lab can be solved:

```bash
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

`astrona test` starts the lab, applies `solution/apply.sh`, submits it, and removes it again. Every lab must pass both `astrona validate` and `astrona test`.

---

## Environment Notes

- **No load balancer on `kind`.** A gateway Service's `EXTERNAL-IP` stays `<pending>`. That is expected, not a fault. The playgrounds with a gateway (040-01, 040-02, 040-03 and 050-01) reach it through the port forwards that `astrona run` keeps open: `127.0.0.1:8080` to the gateway's port `80`, and `127.0.0.1:8443` to its port `443`. The labs tell you which `kubectl port-forward` to start. A port forward also changes the source address the gateway sees, and section 050 uses that on purpose.
- **Outbound internet.** Section 030 uses Istio's published demo tokens (`demo.jwt` and `groups-scope.jwt`) and their key set `jwks.json` from `raw.githubusercontent.com`. Module 040-04 sends requests to `httpbin.org`. Without outbound access you will see key-fetch or network errors instead of the behaviour the pages describe.
- **No sidecars in section 060.** That section runs in ambient mode, so app pods have no `istio-proxy` container. Never use `-c istio-proxy`, or `istioctl proxy-config`, on an app pod there. Use `istioctl ztunnel-config` instead, and point `istioctl proxy-config` only at the waypoint.
