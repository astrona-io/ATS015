# Authenticate End Users With JWT

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS015/tree/main/sections/section-030/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-01/playground
> astrona destroy ats-015-playground-030-01
> ```

Everything in this course so far has authenticated *workloads*: which pod, running as which service account, is making this call. A request usually carries a second identity as well — the **end user** on whose behalf it is being made — and that one arrives as a JSON Web Token in a header, not as a certificate.

Istio handles the two on separate axes, with separate objects. The one that trips people up is not the YAML but a behaviour: `RequestAuthentication` validates a token **if one is present** and does nothing at all about requests that carry none. Protecting a service takes two objects, and knowing which does what is most of this module.

## How this module is organised

1. **[Part 1 — Two identities on one request](./course-01-two-identities-and-the-filter.md)** — peer identity versus request identity, what a JWT is made of, and where the validating filter sits in the request pipeline.
2. **[Part 2 — `RequestAuthentication` and the key set](./course-02-requestauthentication-and-jwks.md)** — `issuer`, `jwksUri`, how keys are fetched and cached, and the three outcomes of validation.
3. **[Part 3 — Requiring a token](./course-03-requiring-a-token.md)** — `requestPrincipals`, why the requirement is an authorization decision, `401` versus `403`, and confirming the filter reached the proxy.

## Learning objectives

After this module you can:

- Distinguish peer identity from request identity, and name the object and policy field belonging to each.
- Describe the three parts of a JWT and say which of them a proxy verifies.
- Place the `jwt_authn` filter in the request pipeline, and explain what it produces for later stages to use.
- Write a `RequestAuthentication` with an `issuer` and `jwksUri`, and say what each is checked against.
- Explain how the key set is fetched and cached, and what an unreachable `jwksUri` does to a workload.
- Explain why a `RequestAuthentication` alone leaves a workload unprotected, and require a token with `requestPrincipals`.
- Tell `401` from `403` in this context, name which object produced each, and say which fix each points at.

## Before you start

You need `AuthorizationPolicy` from [section 020](../../section-020/README.md) — `selector`, `action`, `rules`, and how the first `ALLOW` policy creates default-deny for the workloads it selects. You do not need to know how JWTs are signed; you need to know that a token is a string with three dot-separated parts, that a claim is a key/value pair inside it, and that a signature can be checked against a public key.

The playground gives you a single-node `kind` cluster with **Istio 1.30.5 already installed** (the `demo` profile) and one injected namespace:

- **`jwt-demo`** — `booking-service-v1`, `notification-service-v1` (serving `POST /notify`) and a `tester` client pod.

No `RequestAuthentication` and no `AuthorizationPolicy` exist yet.

This module needs **outbound internet access** from the cluster, twice: once for you to download a demo token, and once for the proxy to fetch the signing keys over HTTPS. Both come from the Istio repository on GitHub. Without outbound access you will see key-fetch failures rather than the behaviour described here.
