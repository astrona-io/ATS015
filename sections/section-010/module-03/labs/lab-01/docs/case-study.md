# Case Study: LAB015-010-03 — Migrate A Namespace To STRICT mTLS

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

`migrate-demo` has been running in the mesh for months, and nobody ever decided
what its mTLS mode should be — it inherited `PERMISSIVE` and stayed there.

Now there is a deadline: the namespace has to be `STRICT` this week. You have a
maintenance window, one caller that is still outside the mesh, and a change
advisory board that will ask you two questions: *how do you know nothing else is
sending plaintext*, and *what is your rollback*.

## What good looks like

- You can point at evidence, not an opinion, that plaintext has stopped arriving.
- The remaining plaintext caller is inside the mesh and still working.
- The namespace is strict, and the change is one object you could revert in
  seconds.
- No application code changed.

## Hints

1. The receiving proxy counts what it handled, and one label on that counter
   answers the board's first question. You have to generate traffic before you
   read it — counters only count what has happened.
2. Labelling a namespace for injection changes nothing about pods already
   running. Work out why, and what that implies about the order of your steps.
3. Do the disruptive step before the enforcing step, not after. The other order
   has a window in which the caller you are fixing is already broken.
4. Before submitting, check that `outside-client` actually has two containers,
   not one.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Do the same migration at mesh scope and list every namespace you had to check first.
- Add a `DestinationRule` with `tls.mode: DISABLE` on the client and reproduce the failure deliberately.
- Use Kiali's security badge to see the same information graphically.
