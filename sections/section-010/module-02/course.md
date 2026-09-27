# Enforce mTLS With PeerAuthentication At Three Scopes

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-010/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-02/playground
> astrona destroy ats-015-playground-010-02
> ```

A fresh mesh encrypts traffic between meshed workloads automatically, and also accepts plaintext from anything that cannot do mutual TLS. Both halves of that sentence are deliberate: the first gives you encryption for free, the second keeps the mesh adoptable in a cluster where not everything is meshed yet.

`PeerAuthentication` is how you turn the second half off. It has one interesting field — a mode — and the whole difficulty of the object is not the field but the **scope**: the same three lines of YAML mean "the entire mesh", "this namespace" or "these pods" depending only on where you put the file and whether it carries a selector.

## How this module is organised

1. **[Part 1 — Modes, and what they do to the inbound listener](./course-01-modes-and-the-inbound-listener.md)** — the four modes, what `PERMISSIVE` actually does inside Envoy, and why a `STRICT` rejection is a connection reset rather than an HTTP error.
2. **[Part 2 — The three scopes and how precedence resolves](./course-02-scopes-and-precedence.md)** — mesh, namespace and workload scope, the narrowest-wins rule, `portLevelMtls`, and the resolution order written out.
3. **[Part 3 — Proving what is in effect](./course-03-proving-what-is-in-effect.md)** — reading enforcement off the proxy instead of inferring it from traffic, the server-side/client-side split, and the pitfalls.

## Learning objectives

After this module you can:

- Explain what `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET` each do, and which one applies when no policy exists.
- Describe how a `PERMISSIVE` listener decides, per connection, whether it is looking at mTLS or plaintext.
- Write a `PeerAuthentication` at mesh, namespace and workload scope, and identify which of the three a given manifest is.
- Apply the narrowest-wins precedence rule to any combination of policies, including a `portLevelMtls` override.
- Recognise the failure signature a non-mesh caller sees when a server goes `STRICT`, and tell it apart from an authorization denial.
- Confirm from a proxy's own configuration that a listener requires a client certificate.
- Explain why `PeerAuthentication` is server-side only, and name the object that decides what a client sends.

## Before you start

You should know what a workload's mesh identity is and that it comes from its service account — [Module 1](../module-01/course.md) covers that. `PeerAuthentication` is the object that decides whether that identity has to be proven on every connection.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and two namespaces:

- **`mtls-demo`** — injected. `booking-service-v1`, `notification-service-v1` and a `tester` client pod, all with sidecars.
- **`outside`** — deliberately **not** injected. One `outside-client` pod with `curl` and no sidecar, so everything it sends is plaintext.

The second namespace is not decoration. Without a caller that *cannot* do mTLS, every experiment in this module returns `200` and proves nothing.

No `PeerAuthentication` exists yet, so the mesh default applies.
