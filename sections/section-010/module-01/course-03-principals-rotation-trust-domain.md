# Part 3 — From SAN to policy principal

> Prerequisite: [Part 2 — Reading the certificate a proxy holds](./course-02-reading-the-certificate.md). Next: [the module landing page](./course.md), then [Module 2 — Enforce mTLS With PeerAuthentication At Three Scopes](../module-02/course.md).

You can now read an identity off a live certificate. This part turns it into the string a policy actually matches on, and covers the two things that change that string underneath you: rotation, which is harmless and constant, and a trust domain change, which is neither.

## The one-character difference that breaks everything

The certificate says:

```text
spiffe://cluster.local/ns/identity-demo/sa/booking-sa
```

An `AuthorizationPolicy` that wants to match this caller writes:

```yaml
    - from:
        - source:
            principals:
              - cluster.local/ns/identity-demo/sa/booking-sa
```

The only difference is the missing `spiffe://` scheme. That asymmetry exists because the two fields are describing different things: the SAN is a URI, which needs a scheme to be a URI at all, while `principals` is a match expression over identity strings, where the scheme would be the same on every entry and carry no information.

Knowing *why* helps, because the failure mode is otherwise baffling. Leaving the scheme on is not a syntax error. The API server accepts the policy, the field is a valid string, the object appears in `kubectl get`, and the rule simply never matches anything — so traffic is denied with no error anywhere to explain it.

The same is true of `namespaces`, which takes bare namespace names, and of the wildcard forms: `cluster.local/ns/identity-demo/sa/*` matches every service account in that namespace, and `*` matches any authenticated principal.

Now that you know what `booking-sa`'s identity is, you can prove it is the value policy matches on. An `ALLOW` policy naming that exact principal should let `booking-service` through and shut everything else out — including `tester`, which runs as `default`.

> [!TIP]
> **Try it — prove the identity is what policy matches on**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: AuthorizationPolicy
> metadata:
>   name: notification-by-identity
>   namespace: identity-demo
> spec:
>   selector:
>     matchLabels:
>       app: notification-service
>   action: ALLOW
>   rules:
>     - from:
>         - source:
>             principals:
>               - cluster.local/ns/identity-demo/sa/booking-sa
> YAML
>
> kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
>   curl -s -o /dev/null -w 'booking: %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n identity-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'tester:  %{http_code}\n' -X POST http://notification-service/notify
> ```
>
> Expect something like:
>
> ```text
> booking: 200
> tester:  403
> ```
>
> This changes cluster state: it creates one policy in `identity-demo`. Undo it with `kubectl -n identity-demo delete authorizationpolicy notification-by-identity`. The `403` is `tester` being refused for having the wrong identity — not the wrong image, port or label. Try editing the principal to end in `sa/default` and watch the two results swap; then try adding `spiffe://` back on the front and watch *both* calls fail.

## Rotation: a lifecycle, not an event

Workload certificates are deliberately short-lived. The default is **24 hours**, and nothing you do keeps one alive longer.

What keeps the workload working is `istio-agent` — the small process that runs alongside Envoy in the sidecar container — refreshing it. The lifecycle it manages looks like this:

```text
   ┌──────────────┐
   │  no cert     │  pod just started
   └──────┬───────┘
          │ CSR + service account token  →  istiod
          ▼
   ┌──────────────┐
   │  ACTIVE      │  in use for every handshake
   └──────┬───────┘
          │ ~50% of lifetime elapsed  →  agent renews, unprompted
          ├──────────────────────────────────┐
          ▼                                  │ istiod unreachable
   ┌──────────────┐                          ▼
   │  ACTIVE      │  new cert, new serial,  ┌──────────────┐
   │  (renewed)   │  same identity          │ still ACTIVE │  retries, works
   └──────────────┘  no restart, no drop    │ until expiry │  until NOT AFTER
                                            └──────┬───────┘
                                                   ▼
                                              handshakes fail
```

Three things in that diagram are examinable, and all three are consequences of the design rather than facts to memorise separately:

- **Renewal happens around halfway through the lifetime**, not at expiry. The gap is deliberate: it leaves roughly twelve hours of retries before anything breaks.
- **Rotation is invisible.** The new certificate reaches Envoy over the same in-pod SDS socket from [Part 1](./course-01-how-identity-is-issued.md). No pod restart, no dropped connection, no configuration change. The serial number changes; the identity does not.
- **A control-plane outage is silent for hours, then total.** Workloads keep working on their current certificates while istiod is down, and start failing when those expire. This is why "everything broke overnight" is a characteristic shape for control-plane problems, and why a stale certificate is a *symptom* of lost istiod connectivity rather than a cause worth chasing on its own.

> [!TIP]
> **Try it — read the validity window**
>
> ```sh
> openssl x509 -in /tmp/workload.crt -noout -dates -serial
> ```
>
> Expect something like:
>
> ```text
> notBefore=Sep 27 09:12:52 2026 GMT
> notAfter=Sep 28 09:14:52 2026 GMT
> serial=285167...
> ```
>
> About 24 hours apart. The dates are examples — yours will reflect when the playground started. Short lifetimes are a security property: a leaked certificate stops being useful within a day, and the cost of that is paid by automation rather than by an operator. Re-extract the certificate after a renewal and the serial will have changed while the SAN has not.

## Changing the trust domain

`meshConfig.trustDomain` defaults to `cluster.local`, and it can be set to something else — commonly an organisation's own domain, so that identities from different clusters do not collide when meshes are joined.

Changing it rewrites the prefix of **every** identity in the mesh. Work through what that means against the issuance flow: istiod computes the SPIFFE URI at signing time, so from the moment the setting changes, every newly issued certificate carries the new prefix. A policy that said `cluster.local/ns/identity-demo/sa/booking-sa` matches nothing once the trust domain becomes `acme.internal`; the correct string is now `acme.internal/ns/identity-demo/sa/booking-sa`. Nothing warns you, because both strings are syntactically valid.

Worse, the change is not instantaneous. Certificates are reissued as they rotate, so for up to a day the mesh holds a mixture of old-prefix and new-prefix identities, and a policy written for either one is wrong for half the traffic.

That is what `meshConfig.trustDomainAliases` is for. It lists additional trust domains the mesh will **accept** on an incoming certificate, so old-prefix and new-prefix identities both verify while policies are updated. It is the mechanism that turns a flag day into a migration.

This is not something to try in the playground: changing the trust domain means re-running `istioctl install` and waiting for every workload to be re-issued, which would take longer than the rest of the module and leave you with an environment that no longer matches the text.

Most of what goes wrong with identity is a string that is one edit away from correct, and none of it produces an error message.

> [!WARNING]
> **Common pitfalls**
>
> - **Writing `spiffe://cluster.local/ns/…` in `principals`** — drop the scheme. `principals` takes `<trust-domain>/ns/<namespace>/sa/<service-account>`, nothing more.
> - **Assuming differently named pods have different identities** — identity is per service account. Two Deployments both running as `default` cannot be told apart by any policy, because they present the same proof.
> - **Hard-coding `cluster.local` after changing the trust domain** — every `principals` value silently stops matching, and for the first day only some of them.
> - **Blaming certificate expiry for an outage** — rotation is automatic and happens hours before expiry. A proxy holding a stale certificate normally means it lost its connection to istiod, so check istiod first.
> - **Looking for the identity in the certificate Subject** — mesh certificates leave it empty and carry the identity in the SAN URI.
> - **Hunting for a Kubernetes Secret holding a workload's key** — there is none. The key is generated in the pod and never leaves it.

## Settling a denial in one pass

When an authorization rule denies traffic you expected to allow, there are only two possible places for the mistake: the identity the caller actually presents, or the string in the policy. Everything in this module exists to make that a two-minute check rather than an afternoon:

Extract the caller's certificate ([Part 2](./course-02-reading-the-certificate.md)), read the SAN, strip `spiffe://`, and compare it character by character with the `principals` entry. Namespace typos, a service account you assumed rather than checked, and a forgotten scheme account for most of what you will find.

The method works in reverse too. Reading someone else's policy, a `principals` value tells you exactly which namespace and service account it was written for, without needing to find the Deployment — because the string is derived, and there is only one workload configuration that could produce it.

> *Read the SAN off the caller, strip `spiffe://`, compare it to the policy — every identity-based denial is settled by that one comparison.*

## Reference

- [AuthorizationPolicy source fields](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `principals`, `namespaces` and their wildcard forms, with the exact expected syntax.
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/) — the certificate lifecycle and rotation behaviour from Istio's side.
- [Trust domain migration](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/) — the documented procedure, including where `trustDomainAliases` fits.
