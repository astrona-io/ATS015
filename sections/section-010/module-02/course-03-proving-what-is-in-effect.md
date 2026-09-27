# Part 3 — Proving what is in effect

> Prerequisite: [Part 2 — The three scopes and how precedence resolves](./course-02-scopes-and-precedence.md). Next: [the module landing page](./course.md), then [Module 3 — Migrate A Namespace From PERMISSIVE To STRICT mTLS](../module-03/course.md).

Every experiment so far concluded something from a status code. That is fine when the result matches the expectation, and useless when it does not: a failed request tells you *something* is refusing traffic, not which object did it or whether your object arrived at all. This part is about getting evidence instead.

## Inventory first, then the proxy

Two commands answer two different questions, and running them in this order saves most of the time.

**What policies exist, anywhere?** `kubectl get peerauthentication -A` lists all of them with their namespaces, which — after [Part 2](./course-02-scopes-and-precedence.md) — is most of what you need to work out the effective mode for any workload. A policy you had forgotten about, or one in the wrong namespace, is visible here and nowhere else.

**Did it reach the proxy, and what did it become?** That is `istioctl proxy-config`, and the answer is a single boolean on the inbound listener.

From [Part 1](./course-01-modes-and-the-inbound-listener.md), `STRICT` means only the `tls` filter chain is programmed. The way that shows up in Envoy's configuration is a transport socket that requires a client certificate.

> [!TIP]
> **Try it — read `requireClientCertificate` off the listener**
>
> ```sh
> kubectl get peerauthentication -A
> istioctl proxy-config listener deploy/notification-service-v1 -n mtls-demo \
>   --port 8084 -o json | grep -i requireClientCertificate
> ```
>
> Expect something like:
>
> ```text
> NAMESPACE      NAME                  AGE
> istio-system   default               12m
> mtls-demo      default               8m
> mtls-demo      notification-strict   5m
>     "requireClientCertificate": true,
> ```
>
> Port `8084` is this application's container port; substitute the port your own workload listens on. The three policies are the three scopes from Part 2, and `true` is the one that won, expressed as configuration rather than inferred from a failed request.

The value is the direct consequence of the mode, so it reads as a decoder:

| Effective mode | `requireClientCertificate` |
| --- | --- |
| `STRICT` | `true` |
| `PERMISSIVE` | `false` (and both filter chains are present) |
| `DISABLE` | no TLS transport socket on that chain at all |

When traffic behaviour and this value disagree, the problem is almost never the rule. It is distribution: a policy in the wrong namespace, a `selector` matching no pod, a `portLevelMtls` entry on a port that does not exist. Those all look identical in `kubectl get` and all show up here as a boolean that did not change.

This is the general habit worth building for every module in this course: **verify with real traffic first, then confirm with `istioctl proxy-config` that the proxy actually received the configuration.**

## `PeerAuthentication` is server-side only

One more asymmetry explains a whole class of confusing failures. `PeerAuthentication` is enforced entirely on the **receiving** side. It says what a workload will accept. It never says what a workload will send.

```text
   client workload                             server workload
   ───────────────                             ───────────────
   what do I SEND?                             what do I ACCEPT?
        │                                            │
   DestinationRule                             PeerAuthentication
   trafficPolicy.tls.mode                      mtls.mode
        │                                            │
   ISTIO_MUTUAL (default between               STRICT / PERMISSIVE / DISABLE
   meshed workloads)
   DISABLE  → plaintext
```

The default on the left is why every in-mesh caller in this module kept working without being touched: meshed clients already send mTLS to meshed servers, so tightening the server changed nothing for them.

The trap is the other value. A `DestinationRule` with `tls.mode: DISABLE` on the client's route makes that client send plaintext to a `STRICT` server, and every request fails — with both sides meshed, both healthy, and nothing in either pod's spec to suggest why. When a rollout breaks exactly one caller while others succeed, a stale `DestinationRule` on that caller's route is the first thing to look for. [Module 3](../module-03/course.md) returns to this during a live migration.

Most of what goes wrong with this object is scope rather than mode, and the mistakes look like successes until traffic proves otherwise.

> [!WARNING]
> **Common pitfalls**
>
> - **A mesh-wide policy in the wrong namespace** — only the root namespace (normally `istio-system`) is mesh-wide. In any other namespace the identical YAML is a namespace policy.
> - **An accidental `selector` on a namespace policy** — it silently becomes a workload policy covering far fewer pods, with no error.
> - **Expecting `403` from a `STRICT` rejection** — you get a connection reset (`000` from `curl`). `403` comes from authorization, which runs later and only on connections that were accepted.
> - **`portLevelMtls` on a `Service` port, or on a port nothing listens on** — it takes the container port, and an entry with no matching listener does nothing at all, silently.
> - **Expecting more policies to be more restrictive** — narrowest wins outright, so a `PERMISSIVE` namespace policy really does override a `STRICT` mesh policy.
> - **Turning on `STRICT` before knowing who still speaks plaintext** — every unmeshed caller breaks at once. [Module 3](../module-03/course.md) is about doing this safely.
> - **Assuming `STRICT` means "only allowed callers"** — it means "only callers that can prove *an* identity". Deciding *which* identities may do *what* is `AuthorizationPolicy`'s job, in [section 020](../../section-020/README.md).

## Operational properties

**Changes take effect in seconds, without restarting anything.** A policy is pushed to running proxies as a configuration update, exactly like the certificates in [Module 1](../module-01/course.md). That cuts both ways: a bad `STRICT` breaks callers immediately, and deleting it fixes them just as fast. Keeping the previous manifest to hand is a cheap and complete rollback.

**Ordering matters during a rollout.** Because enforcement is server-side, the safe sequence is always to make clients capable of mTLS *first* and tighten the server *afterwards*. Doing it the other way round means a window in which the server rejects callers that were about to be fixed.

**`STRICT` protects the transport, not the application.** It guarantees that whoever connected holds a valid mesh certificate. Any workload in the mesh satisfies that — including ones that have no business calling this service at all. `STRICT` is the precondition that makes identity-based authorization meaningful, not a substitute for it.

> *`PeerAuthentication` says what a workload accepts; a `DestinationRule` says what it sends — and `requireClientCertificate` on the listener is the only direct evidence of which mode won.*

## Reference

- [`istioctl proxy-config listener`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-listener) — flags including `--port` and `-o json`, which is where `requireClientCertificate` appears.
- [DestinationRule TLS settings](https://istio.io/latest/docs/reference/config/networking/destination-rule/#ClientTLSSettings) — the client-side half, including `ISTIO_MUTUAL` and `DISABLE`.
- [Istio authentication policy task](https://istio.io/latest/docs/tasks/security/authentication/authn-policy/) — Istio's own verification steps for each scope.
