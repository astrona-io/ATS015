# Originate TLS For External Services

Astronaut, your ships often send signals to planets in other solar systems: public services on the internet, outside your cluster. This outgoing traffic is called **egress**. Most of those planets only accept HTTPS, so the signal has to be sealed with **TLS** (Transport Layer Security), the encryption behind HTTPS. Think of TLS as a sealed envelope that only the receiver can open.

The question is **who seals the envelope**. If the app seals it, its communications officer (the sidecar proxy) only sees a sealed envelope. It cannot read the path, the headers or the status code, so Istio's request features stop working.

**TLS origination** moves the sealing job into the sidecar. The app sends a plain HTTP signal to its own sidecar. The sidecar reads it, applies your rules, and then seals it before it leaves the ship. The signal on the wire is still HTTPS, and the mesh can still see every request.

> With TLS origination, the app speaks plain HTTP to its own sidecar, and the sidecar seals the signal with TLS before it leaves the ship.

## Learning objectives

After this module you can:

- Explain who does the TLS when the app calls `https://`, and when the sidecar originates TLS.
- Set up TLS origination with a `ServiceEntry` port that uses `targetPort: 443` and a `DestinationRule` with `tls.mode: SIMPLE`.
- Prove that the sidecar sealed the signal, from the outside server's answer, the flight log and the proxy's configuration.
- Check the outside server's certificate name with `subjectAltNames`.
- Tell the three typical failures apart: `400`, `WRONG_VERSION_NUMBER` and `CERTIFICATE_VERIFY_FAILED`.
- Use a request feature, a timeout, on an outside HTTPS service.

## Before you start

Every mission starts with a pre-flight check. Make sure you know the three Istio objects this module uses, and what is waiting in your playground.

### What you should already know

TLS origination combines three Istio objects. None of them is new on its own:

- A **`ServiceEntry`** adds a planet from another solar system to the star chart (the list of places the mesh knows about), so the sidecars know its name and its ports.
- A **`DestinationRule`** holds the docking instructions for one destination: how a sidecar connects to it, including TLS.
- A **`VirtualService`** is the flight plan: it decides where a signal goes and how it is handled, for example with a timeout.

You should also know Kubernetes basics: namespaces, Deployments, pods and `kubectl exec`.

### What is in your playground

Your playground is a training solar system: one `kind` cluster with **Istio 1.30.5** installed. The mesh is at its `ALLOW_ANY` default, so ships may signal any outside planet. The planet (namespace) **`starfleet`** holds the **`shuttle`**, your test client with `curl`. It has its sidecar, and every sidecar writes a flight log (access log) line for each signal.

There is **no** `ServiceEntry`, `DestinationRule` or `VirtualService` yet. Writing them is your mission. No gateway is needed either: the shuttle's own sidecar does the sealing.

The commands call `httpbin.org` on the internet, a public test service that echoes back what it received. **Without outbound internet access you see network errors instead of mesh behaviour.**

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts

1. **[Who Seals The Signal](./course-01-who-seals-the-signal.md)**: what the sidecar can and cannot see in an HTTPS signal, the three places a seal can be added, and the four `tls` modes of a `DestinationRule`.
2. **[Chart The Planet And Seal The Signal](./course-02-chart-the-planet-and-seal-the-signal.md)**: the `ServiceEntry` with `targetPort: 443`, the `DestinationRule` with `tls.mode: SIMPLE`, and three ways to prove the sidecar sealed the signal.
3. **[Check The Planet's ID Card](./course-03-check-the-planets-id-card.md)**: `subjectAltNames`, what a wrong name looks like, and why `sni` alone checks nothing. Then the mission *Seal The Signal To An Outside Planet Lab*.
4. **[A Seal On The Wrong Channel](./course-04-a-seal-on-the-wrong-channel.md)**: the missing `targetPort`, and a table of the three failures and their causes.
5. **[Use What You Won](./course-05-use-what-you-won.md)**: a timeout on an outside HTTPS service, and what changes for `MUTUAL` TLS.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, your mission, and questions to check yourself.
