# Originate TLS For External Services

Pods in your mesh often send requests to services outside the cluster, for example public services on the internet. This outgoing traffic is called **egress** traffic. Most of those services only accept HTTPS, so the request must be encrypted with **TLS** (Transport Layer Security), the encryption protocol behind HTTPS.

The question is **who starts the TLS connection**. If the app starts it, the **sidecar proxy** (Envoy, a proxy container Istio adds to each pod; all inbound and outbound traffic of the pod passes through it) only sees encrypted bytes. It cannot read the path, the headers or the status code, so Istio's request features stop working.

**TLS origination** moves the TLS job into the sidecar proxy. The app sends a plain HTTP request to its own sidecar. The sidecar reads it, applies your rules, and then encrypts it with TLS before it leaves the pod. The request on the network is still HTTPS, and the mesh can still see every request.

> With TLS origination, the app speaks plain HTTP to its own sidecar, and the sidecar encrypts the request with TLS before it leaves the pod.

## Learning objectives

After this module you can:

- Explain who does the TLS when the app calls `https://`, and when the sidecar originates TLS.
- Set up TLS origination with a `ServiceEntry` port that uses `targetPort: 443` and a `DestinationRule` with `tls.mode: SIMPLE`.
- Prove that the sidecar started the TLS connection, from the outside server's response, the access log and the proxy's configuration.
- Check the outside server's certificate name with `subjectAltNames`.
- Tell the three typical failures apart: `400`, `WRONG_VERSION_NUMBER` and `CERTIFICATE_VERIFY_FAILED`.
- Use a request feature, a timeout, on an outside HTTPS service.

## Before you start

This section lists what you need to know before you start, and what the playground gives you. Make sure you know the three Istio objects this module uses.

### What you should already know

TLS origination combines three Istio objects. None of them is new on its own:

- A **`ServiceEntry`** adds an external host to Istio's service registry (the list of services the mesh knows about), so the sidecars know its name and its ports.
- A **`DestinationRule`** sets the traffic policy for one destination: how a sidecar connects to it, including TLS.
- A **`VirtualService`** holds routing rules: it decides where a request goes and how it is handled, for example with a timeout.

You should also know Kubernetes basics: namespaces, Deployments, pods and `kubectl exec`.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5** installed. The mesh is at its `ALLOW_ANY` default, so pods may send requests to any outside host. The namespace **`starfleet`** holds the **`shuttle`** pod, your test client with `curl`. It has its sidecar, and every sidecar writes an access log line for each request.

There is **no** `ServiceEntry`, `DestinationRule` or `VirtualService` yet. You write them in this module. No gateway is needed either: the `shuttle` pod's own sidecar starts the TLS connection.

The commands call `httpbin.org` on the internet, a public test service that echoes back what it received. **Without outbound internet access you see network errors instead of mesh behaviour.**

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts

1. **[Who Starts The TLS Connection](./course-01-who-seals-the-signal.md)**: what the sidecar can and cannot see in an HTTPS request, the three places TLS can be started, and the four `tls` modes of a `DestinationRule`.
2. **[Originate TLS With A ServiceEntry And A DestinationRule](./course-02-chart-the-planet-and-seal-the-signal.md)**: the `ServiceEntry` with `targetPort: 443`, the `DestinationRule` with `tls.mode: SIMPLE`, and three ways to prove the sidecar started the TLS connection.
3. **[Verify The Server Certificate Name](./course-03-check-the-planets-id-card.md)**: `subjectAltNames`, what a wrong name looks like, and why `sni` alone checks nothing. Then the lab *Originate TLS To An External Service Lab*.
4. **[Diagnose TLS Origination Failures](./course-04-a-seal-on-the-wrong-channel.md)**: the missing `targetPort`, and a table of the three failures and their causes.
5. **[Add A Timeout And Mutual TLS To An External Service](./course-05-use-what-you-won.md)**: a timeout on an outside HTTPS service, and what changes for `MUTUAL` TLS.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, the lab, and questions to check yourself.
