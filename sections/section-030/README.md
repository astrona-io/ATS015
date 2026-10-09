# End-User Authentication With JWT

A request usually carries two identities: the workload making the call, and the end user on whose behalf it is made. The first is the workload identity in a certificate, which mutual TLS (mTLS) verifies on every connection. This section covers the second, which arrives as a JSON Web Token in a header rather than as a certificate.

Two modules, and the first exists mainly to correct an expectation. Module 1 shows that `RequestAuthentication` validates a token *if one is present* and requires nothing — so protecting a service always takes two objects. Module 2 goes past "a valid token exists" to what the token actually says, matching on claims such as `groups` and `scope`.

**Curriculum items covered:** Configuring Authentication (mTLS, JWT) — module 1; Configuring Authorization — module 2.

---

## What You Will Master

- `RequestAuthentication` with `issuer` and `jwksUri`, and that `issuer` is compared to the `iss` claim as an exact string.
- Why a `RequestAuthentication` alone leaves a workload unprotected, and how `requestPrincipals` in an `AuthorizationPolicy` makes a token mandatory.
- The request principal form `<issuer>/<subject>`, and `["*"]` for any valid token.
- `401` versus `403` here: which object produced each, and which fix each points at.
- Reading the token from another place with `fromParams` or `fromHeaders`, and writing "token required" as a `DENY` policy with `notRequestPrincipals`.
- The request attributes a validated token exposes — `request.auth.principal`, `request.auth.audiences`, `request.auth.claims[...]`.
- `when` conditions: values inside one entry ORed, multiple entries ANDed, and a list claim matching if any element matches.
- That a missing claim never matches, so a `when` condition fails closed under `ALLOW` and open under `DENY`.
- Building one policy with one rule per role, including a public path, and pairing claim rules with `requestPrincipals`.

---

<!-- astrona:playground -->