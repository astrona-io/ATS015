# Welcome To The Course

This course trains you for the **Securing Workloads** part of the **Istio Certified Associate (ICA)** exam. That part is 25% of the exam.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl logs` and `kubectl exec`. You do not need to know Istio yet, and you do not need to be a security expert. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a live cluster and a list of tasks, and you have to make them work. So this course does not ask you to remember words. It asks you to *do* things, and to prove they work.

The exam groups this part into three topics. Here is what each one means for you.

### Proving who is talking (authentication)

Authentication means checking who sent a request. You will learn to:

- Find the identity Istio gives every workload, and read it from its certificate. A certificate is a signed file that a program presents to prove who it is.
- Turn on **mutual TLS (mTLS)** with `PeerAuthentication`. With mutual TLS, both sides of a connection present a certificate, so the traffic is encrypted and each side knows who the other is.
- Move a live namespace to strict mTLS without cutting off its callers.
- Check a user's **JSON Web Token (JWT)** with `RequestAuthentication`. A JWT is a signed token that carries facts (claims) about the end user, and it travels with each request.

### Deciding who may do what (authorization)

Authorization means deciding if a request is allowed, once you know who sent it. You will learn to:

- Write `AuthorizationPolicy` rules that allow or deny requests by workload identity, path, method or token claim.
- Know the order Istio checks rules in, and why one missing rule can lock everything out.
- Apply rules at the ingress gateway, the proxy at the edge of the mesh that accepts traffic from outside the cluster.
- Do the same in **ambient mode**, a newer way to run Istio with no proxy inside each pod.

### Securing traffic at the edge (TLS)

TLS (Transport Layer Security) encrypts a connection, so nobody on the network can read or change the request while it travels. You will learn to:

- Serve HTTPS at the ingress gateway.
- Ask outside clients for their own certificate before you let them in.
- Pass an encrypted stream straight through the gateway without decrypting it.
- Add TLS to requests that leave the mesh for a service outside it.

You will also learn to find out *why* something does not work, by asking the proxy what rules and certificates it actually holds.

Everything is built and checked on **Istio 1.30.5**.

## The words this course uses

The pages use Istio's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the exam. Each term gets a short, plain definition the first time it appears on a page. Here are the most important ones:

- A **pod** runs one copy of an application. A **namespace** groups pods and other objects inside the cluster.
- A **request** is one call that a client sends to a server, and the **response** is the answer it gets back.
- The **sidecar proxy** (Envoy) is a proxy container that Istio adds to each pod. All traffic in and out of the pod passes through it.
- **`istiod`** is Istio's control plane. It sends configuration and certificates to every proxy.

## The example app in your playground

Every playground runs **the Starfleet**: the Istio Bookinfo sample app with space names. It runs in the namespace `starfleet`. The `bridge` is the web frontend, and it calls the `cargo` backend and three versions of the `scout` backend. You send your test requests from the `shuttle` client pod.

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

Each section has one or more **modules**. A module has four kinds of pages:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, then a few parts that teach one idea each | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A task, a live cluster, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, using everything in it at once | Yes |

The best order for each module: read the parts with the playground open next to them. When a part ends with **Your mission**, pause the playground and take that lab without looking at the solution. Then wake the playground up and read on.

The last page of every module is a wrap-up that lists its labs and cleans up the playground. Finish each section with its capstone.

## How to read a page

Most parts follow the same pattern. Short hands-on steps sit right in the page, each under its own small heading: one sentence on what to do, the command, the real output, and what it shows. Run them in your playground. You learn more from one real result than from a page of text.

Two kinds of boxes come back often:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every part ends with one.

Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
