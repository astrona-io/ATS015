# Welcome To The Course

This course trains you for the **Securing Workloads** part of the **Istio Certified Associate (ICA)** exam. That part is 25% of the exam. This page tells you who the course is for, what you can do at the end, which words and example app it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl logs` and `kubectl exec`. You do not need to know Istio yet, and you do not need to be a security expert. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a live cluster and a list of tasks, and you have to make them work. So this course does not ask you to remember words. It asks you to *do* things, and to prove they work. The exam groups this part into three topics, and each one turns into a set of skills you will practise.

The first topic is **authentication**, which means checking who sent a request. A certificate plays the main role here: it is a signed file that a program presents to prove who it is. You will learn to:

- Find the identity Istio gives every workload, and read it from its certificate.
- Turn on **mutual TLS (mTLS)** with `PeerAuthentication`. With mutual TLS, both sides of a connection present a certificate, so the traffic is encrypted and each side knows who the other is.
- Move a live namespace to strict mTLS without cutting off its callers.
- Check a user's **JSON Web Token (JWT)** with `RequestAuthentication`. A JWT is a signed token that carries facts (claims) about the end user, and it travels with each request.

Once you know who sent a request, the second topic, **authorization**, decides if the request is allowed. You will learn to:

- Write `AuthorizationPolicy` rules that allow or deny requests by workload identity, path, method or token claim.
- Know the order Istio checks rules in, and why one missing rule can lock everything out.
- Apply rules at the ingress gateway, the proxy at the edge of the mesh that accepts traffic from outside the cluster.
- Do the same in **ambient mode**, a newer way to run Istio with no proxy inside each pod.

The third topic is **TLS at the edge**. TLS (Transport Layer Security) encrypts a connection, so nobody on the network can read or change the request while it travels. You will learn to:

- Serve HTTPS at the ingress gateway.
- Ask outside clients for their own certificate before you let them in.
- Pass an encrypted stream straight through the gateway without decrypting it.
- Add TLS to requests that leave the mesh for a service outside it.

Across all three topics, you will also learn to find out *why* something does not work, by asking the proxy what rules and certificates it actually holds. Everything is built and checked on **Istio 1.30.5**.

## The words this course uses

The pages use Istio's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the exam. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **pod** runs one copy of an application, and a **namespace** groups pods and other objects inside the cluster. A **request** is one call that a client sends to a server, and the **response** is the answer it gets back. The **sidecar proxy** (Envoy) is a proxy container that Istio adds to each pod; all traffic in and out of the pod passes through it. **`istiod`** is Istio's control plane, and it sends configuration and certificates to every proxy.

Five Istio objects do the security work in this course. `istiod` turns each one into configuration for the Envoy proxies:

| Object | What it does |
| --- | --- |
| `PeerAuthentication` | Sets whether a workload accepts only mTLS, only plain text, or both, on inbound connections |
| `RequestAuthentication` | Validates the JWT on a request, if the request carries one |
| `AuthorizationPolicy` | Allows or denies requests by caller, path, method or token claim |
| `Gateway` (its `tls` block) | Sets TLS at the edge of the mesh: `SIMPLE`, `MUTUAL` or `PASSTHROUGH` |
| `DestinationRule` (its `tls` block) | Sets the TLS the calling side sends: `ISTIO_MUTUAL`, `SIMPLE`, `MUTUAL` or `DISABLE` |

## The example app in your playground

You will see these objects at work on one example app. Every playground runs **the Starfleet**: the Istio Bookinfo sample app with space names. It runs in the namespace `starfleet`. The `bridge` is the web frontend, and it calls the `cargo` backend and three versions of the `scout` backend. You send your test requests from the `shuttle` client pod.

There is also the `drifter` client pod in the namespace `outpost`. It has no sidecar proxy, so it has no certificate and can only send plain text. It shows you what happens to a caller outside the mesh when you turn on strict rules.

Some graded labs use a small app of their own instead, such as `booking-service` or `notification-service`. The lab's task says so when that is the case.

## How the course is laid out

The course has six sections. Each section covers one part of the exam topics above:

| Section | What it covers |
| --- | --- |
| 010 | Workload Identity And Mutual TLS |
| 020 | Authorization Policy Fundamentals |
| 030 | End-User Authentication With JWT |
| 040 | Securing Edge Traffic With TLS |
| 050 | Authorization At The Edge |
| 060 | Authorization In Ambient Mode |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A task, a live cluster, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, using everything in it at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, the real output, and then what that output shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, the lab comes right after that chapter: first a page with its task, then the lab itself. Solve the lab on your own before you look at its solution.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page shows you how to remove the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
