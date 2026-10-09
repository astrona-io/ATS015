# Welcome, Astronaut

This course trains you for the **Securing Workloads** part of the **Istio Certified Associate (ICA)** exam. That part is 25% of the exam.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl logs` and `kubectl exec`. You do not need to know Istio yet, and you do not need to be a security expert. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a live cluster and a list of tasks, and you have to make them work. So this course does not ask you to remember words. It asks you to *do* things, and to prove they work.

The exam groups this part into three topics. Here is what each one means for you.

### Proving who is talking (authentication)

Authentication means checking who sent a signal. You will learn to:

- Find the identity Istio gives every workload, and read it from its certificate. A certificate is a signed ID card that a program can show to prove who it is.
- Turn on **mutual TLS (mTLS)** with `PeerAuthentication`. Mutual TLS is a secret handshake both ships check before they talk, so every signal is encrypted and both sides know who the other is.
- Move a live namespace to strict mTLS without cutting off its callers.
- Check a user's **JSON Web Token (JWT)** with `RequestAuthentication`. A JWT is a signed boarding pass a user carries on each signal.

### Deciding who may do what (authorization)

Authorization means deciding if a signal is allowed in, once you know who sent it. You will learn to:

- Write `AuthorizationPolicy` rules that allow or deny signals by workload identity, path, method or token claim.
- Know the order Istio checks rules in, and why one missing rule can lock everything out.
- Apply rules at the ingress gateway, the one door signals from outside come through.
- Do the same in **ambient mode**, a newer way to run Istio with no proxy inside each pod.

### Locking the borders (edge traffic with TLS)

TLS (Transport Layer Security) is the lock that keeps a signal private while it travels. You will learn to:

- Serve HTTPS at the ingress gateway.
- Ask outside clients for their own certificate before you let them in.
- Pass an encrypted stream straight through the gateway without opening it.
- Add TLS to signals that leave the mesh for a service outside it.

You will also learn to find out *why* something does not work, by asking the proxy what rules and certificates it actually holds.

Everything is built and checked on **Istio 1.30.5**.

## The picture we use: space

Istio has a lot of new words. To make them stick, this course uses one picture from start to finish: space.

You are an astronaut. Your Kubernetes cluster is a **solar system**. Each namespace is a **planet**, and each pod is a **spaceship**. A request one ship sends to another is a **signal**.

Istio puts a **communications officer** on board every ship: the sidecar proxy. Every signal in or out goes through them. **Mission control** (`istiod`) gives every communications officer their orders, and it also hands out each ship's ID card. Each page uses one short picture like this the first time a new word appears, and then sticks to the real term.

## The fleet in your playground

Every playground runs **the Starfleet**: a small sample app with space names. It lives on the planet `starfleet`. The `bridge` is the main page, and it calls the `cargo` ship and three classes of `scout`. You send your test signals from the `shuttle`.

There is also the `drifter` on the planet `outpost`. It flies without a communications officer, so it cannot do the secret handshake. It shows you what happens to a caller outside the mesh when you lock things down.

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
| **Playground** | A training solar system on your own machine, to try everything you read | No |
| **Lab** | A real mission: a task, a live cluster, and a grader that checks your work | Yes |
| **Capstone** | The last mission in a section, using everything in it at once | Yes |

The best order for each module: read the parts with the playground open next to them. When a part ends with **Your mission**, pause the playground and take that lab without looking at the solution. Then wake the playground up and read on.

The last page of every module is a wrap-up that lists its missions and cleans up the playground. Finish each section with its capstone.

## How to read a page

Most parts follow the same pattern. Short hands-on steps sit right in the page, each under its own small heading: one sentence on what to do, the command, the real output, and what it shows. Run them in your playground. You learn more from one real result than from a page of text.

Two kinds of boxes come back often:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every part ends with one.

Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
