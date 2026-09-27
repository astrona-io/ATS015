# Case Study: CAP015-010 — Workload Identity And Mutual TLS Capstone

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

Two tickets landed in the same sprint.

The first is a security requirement: mutual TLS everywhere, no exceptions, signed
off at the mesh level rather than namespace by namespace.

The second is from the booking team: their notification service is being called
by things that have no business calling it, and they want that stopped in a way
that does not depend on pod names or IP addresses.

There is one complication. A caller in another namespace is still outside the
mesh, and turning on the first ticket without dealing with it breaks production.

## What good looks like

- The strict default is visible as a single mesh-level object.
- The unmeshed caller is inside the mesh and still working — and nobody found out
  about it from an incident.
- The notification service refuses everything except one verified identity.
- You can explain, for each failed call, whether the transport or a policy
  refused it.

## Hints

1. Sequencing is the whole capstone. One of the three parts is disruptive, and
   doing it after the others means a window where a caller is already broken.
2. A namespace label is not a migration. Work out what actually puts a sidecar
   into a running pod.
3. The mesh scope has a specific home, and putting the object anywhere else turns
   it into something much narrower without any error.
4. Before submitting, make sure the two failures you expect fail for different
   reasons — a `403` and a dropped connection are not interchangeable.
