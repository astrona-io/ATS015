# Summary

A request can carry two identities: the workload that sends it and the end user it is sent for. This module was about the end user: how a proxy checks their token, and how a policy makes that token required.

## What you learned

The workload's identity, the peer identity, comes from its mTLS (mutual TLS) certificate and goes in the `principals` field of an `AuthorizationPolicy`. The end user's identity, the request identity, comes from a JWT (JSON Web Token) and goes in `requestPrincipals`. A certificate proves one hop at a time; a token can be passed on, so it travels end to end.

A JWT has three parts, header, payload and signature, and the payload holds claims such as `iss`, `sub`, `exp` and `aud`. Anyone can decode a token. Only the signature check against the issuer's JWKS (JSON Web Key Set) proves it is real.

A `RequestAuthentication` tells the receiving sidecar proxy how to check tokens. Its `issuer` must match the token's `iss` claim letter for letter, and its `jwksUri` says where the public keys live. `istiod` downloads those keys and puts them in the proxy's configuration, so every request is checked locally.

A bad token gets `401`. If `istiod` cannot reach the keys, or the issuer string is slightly wrong, every token gets `401`, even good ones, and `istioctl proxy-config listener` shows what the proxy really holds.

The surprise is that a `RequestAuthentication` never requires a token. A request without one passes the check with no identity attached.

To require a token, an `ALLOW` policy with `requestPrincipals: ["*"]` refuses every request that has no request principal, with `403`. The same requirement can be written as `DENY` with `notRequestPrincipals: ["*"]`. That form only refuses requests without a token and leaves every other rule as it was.

The status code tells you where to look. The key facts to remember are these:

- `401` with a `Jwt ...` body comes from the `RequestAuthentication`: check the token, the issuer and the keys.
- `403` with `RBAC: access denied` comes from the `AuthorizationPolicy`: check the policy, not the token.
- A request principal is `<iss>/<sub>`; `["*"]` means any valid token.
- Apply the `RequestAuthentication` first and the policy second, and remove them in the reverse order. In the other order, every request is refused.
- With `fromParams` or `fromHeaders` set, the proxy reads only that place, so a token in the `Authorization` header gets `403`.

In short: a `RequestAuthentication` validates the token, and an `AuthorizationPolicy` decides which requests must carry one. Protecting a workload always takes both.

<!-- astrona:playground:destroy -->
