# Case Study: LAB015-010-02 — Enforce mTLS At Three Scopes

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Security has signed off on a mesh-wide rule: everything must use mutual TLS.

One team cannot comply yet. Their namespace still has a caller running outside
the mesh, and they need a few weeks. You agree an exception — with one condition:
the service handling notifications is the sensitive one, and it does **not** get
the exception, even though it lives in the same namespace.

So you need three decisions at three different widths, and the narrow ones have
to win.

## What good looks like

- Somebody reading the mesh's configuration can see the strict default.
- The exception is visible as a deliberate object, scoped to one namespace.
- The sensitive workload rejects plaintext while its neighbour in the same
  namespace accepts it.
- No application was changed to achieve any of this.

## Hints

1. The scope of a `PeerAuthentication` is not a field. Two things decide it —
   where the object lives, and whether it carries a selector.
2. One of the three objects goes somewhere other than `mtls-demo`. Getting that
   wrong produces a second namespace policy, silently.
3. When several policies could apply, exactly one decides — and it is not the
   most restrictive one.
4. Check your own work from `outside-client`, calling both services. You are
   looking for a difference between them, and for the failing one to fail at the
   transport (`000`) rather than with an HTTP status.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Add `portLevelMtls` to keep one port PERMISSIVE while the workload is otherwise STRICT.
- Set `DISABLE` on one workload and observe how it interacts with a STRICT mesh policy.
- Use `istioctl x describe pod <pod>` and read the mTLS section it prints.
