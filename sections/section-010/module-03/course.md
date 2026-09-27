# Migrate A Namespace From PERMISSIVE To STRICT mTLS

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-010/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-03/playground
> astrona destroy ats-015-playground-010-03
> ```

Writing `mode: STRICT` takes ten seconds. Knowing that it is safe to write is the actual work, and it is the part a real cluster punishes you for skipping: every caller still sending plaintext breaks the moment the policy lands, with a connection reset that surfaces in *their* logs rather than yours.

This module is the procedure, not the object. The object you already know from [Module 2](../module-02/course.md). What is new is the order of operations — measure, exempt, mesh, enforce — and the mechanisms underneath each step that decide whether it actually worked.

## How this module is organised

1. **[Part 1 — Measuring before you change anything](./course-01-measuring-with-telemetry.md)** — where the sidecar's counters live, the `connection_security_policy` label, and what this measurement cannot tell you.
2. **[Part 2 — Exceptions, and moving callers into the mesh](./course-02-exceptions-and-meshing.md)** — declaring the current state, `portLevelMtls` for what cannot be fixed, and the admission-webhook mechanics that make injection need a restart.
3. **[Part 3 — Enforcing, verifying and rolling back](./course-03-enforcing-and-rolling-back.md)** — the flip itself, the client-side setting that breaks it anyway, rollback, and the procedure compressed into six steps.

## Learning objectives

After this module you can:

- Read the `connection_security_policy` label off `istio_requests_total` on the receiving proxy, and say why it is read there rather than on the caller.
- State what a counter-based measurement cannot prove, and how long a measurement window needs to be.
- Write an explicit `PERMISSIVE` policy and explain the two reasons for declaring a state you are already in.
- Write a `portLevelMtls` exception using the correct port, and recognise the silent failure when the port is wrong.
- Explain why labelling a namespace for injection changes nothing about running pods.
- Order the steps of a `PERMISSIVE`-to-`STRICT` migration and say what each one protects against.
- Name the client-side setting that breaks a `STRICT` server even when both sides are meshed, and how to roll back in seconds.

## Before you start

You need [Module 2](../module-02/course.md): `PeerAuthentication`, its three scopes, the narrowest-wins rule, and what a `STRICT` rejection looks like from the caller's side (`000`, a connection reset — not `403`).

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and two namespaces:

- **`migrate-demo`** — injected. `booking-service-v1`, `notification-service-v1` (container port `8084`) and a `tester` client pod.
- **`outside`** — not injected. One `outside-client` pod, which you will migrate into the mesh during the module.

No `PeerAuthentication` exists, so `migrate-demo` is implicitly `PERMISSIVE`. That is the realistic starting point: a namespace where the mode was never decided, only inherited.

## Where this fits

Every mesh adoption passes through this state. `PERMISSIVE` exists precisely so that turning on the mesh is not a flag day — a server accepts both kinds of traffic while its callers are moved across one at a time. The risk is that `PERMISSIVE` is comfortable, so namespaces sit in it for months, and by the time someone enforces `STRICT` nobody remembers which callers were ever migrated. The telemetry step in [Part 1](./course-01-measuring-with-telemetry.md) is what replaces that memory.
