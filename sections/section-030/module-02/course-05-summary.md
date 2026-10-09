# Summary

A valid token only says that a user logged in. Real access control asks what the token says. This module showed how the claims in a JWT (JSON Web Token) reach an `AuthorizationPolicy`, how to write rules on them, and how to find out why a claim rule refuses the wrong user.

## What you learned

Two filters in the sidecar proxy share the work. The JWT filter, configured by the `RequestAuthentication`, checks the token and answers `401` if it is bad. It then publishes the token's facts as `request.auth` attributes, such as `request.auth.principal` and `request.auth.claims[groups]`. The authorization filter, configured by the `AuthorizationPolicy`, reads those attributes and answers `403` when no rule fits. Without a `RequestAuthentication` on the workload, nothing is published and no claim rule can fit.

Every claim rule is a text comparison, so you read a real token before you write one. The payload of a JWT is base64 text that anyone can decode. The two sample tokens have the same principal and different claims, which is exactly the case where only a claim rule can tell users apart. A claim is only as trustworthy as its issuer, and it stays true until the token expires.

A `when` condition is one part of a rule, and four rules decide when it fits. Values in one entry are OR, several entries are AND, and a `when` is AND with `from` and `to`. A list claim such as `groups` fits if any of its items is in `values`, with no special list syntax. A valid token that lacks the claim gets `403`, not `401`.

One `ALLOW` policy per workload, with one rule per role, holds the workload's whole access model in one place. Rules in one policy are OR, so a rule with only `to: paths` and no `from` makes a public path. A claim rule paired with `requestPrincipals: ["*"]` writes the token requirement down. A missing claim fails closed under `ALLOW` and open under `DENY`, so requirements belong in `ALLOW` rules.

A wrong claim name gives no error anywhere. The key facts for debugging one are these:

- `istioctl analyze` does not know your issuer's claim names, so a clean result proves little.
- `istioctl proxy-config listener <pod> -o json`, filtered for the keys under `"payload"`, shows the claim names the proxy really compares.
- No claim names at all means the policy's `selector` reaches no pod.
- Comparing the proxy's claim names with the decoded token, letter by letter, settles the fault.

In short: read the token, write one `ALLOW` rule per role, and when a claim rule refuses everyone, compare what the proxy holds with what the token says.

<!-- astrona:playground:destroy -->
