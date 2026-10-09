# Summary

An `AuthorizationPolicy` with `action: DENY` closes what must stay closed, whatever any other policy says. This module showed why that holds: the sidecar proxy of the receiving pod checks policies in a fixed order, and a `DENY` match ends the decision.

## What you learned

The sidecar proxy checks `CUSTOM` policies first, then `DENY`, then `ALLOW`. A `CUSTOM` rejection or a `DENY` match ends the decision, so no `ALLOW` policy is ever read after it. There is no "most specific wins" for `AuthorizationPolicy`: a `DENY` match beats every `ALLOW`, however narrow. An exception to a `DENY` therefore has to live inside the `DENY` itself, for example with `notPaths`.

A `DENY` does not turn on default-deny. A workload with only `DENY` policies still allows everything they do not match, and only an `ALLOW` policy makes the sidecar proxy refuse unmatched requests. Both a `DENY` hit and an `ALLOW` miss give the caller the same `403` with the body `RBAC: access denied`. The receiving pod's access log tells them apart: it names the policy and rule in `rbac_access_denied_matched_policy[...]`, or shows `matched_policy[none]`.

The number of rules in a policy changes everything. `spec: {}` has no rules, so it fits nothing and allows nothing. `rules: [{}]` has one empty rule, so it fits every request and allows everything. `action: DENY` with `rules: [{}]` denies every request, even with an open `ALLOW` policy in place. A policy without a `selector` covers every pod in its namespace, and in `istio-system` every pod in the mesh.

Narrow `DENY` rules fail quietly when they are too narrow. An exact path such as `/admin` leaves `/admin/users` open, while a prefix such as `/admin*` closes the whole area. A part you leave out of a `DENY` rule matches everything. Negative fields such as `notMethods`, `notPaths` and `notPrincipals` mean "everything except", so read each policy as a sentence that starts with the action: `DENY` with `notMethods: ["GET"]` refuses every method except `GET`.

`AUDIT` records a match and never changes the response, and it needs an audit provider in the mesh to record anywhere. That makes it a safe way to try a new rule before you patch its action to `DENY`. The key facts to remember are these:

- Order: `CUSTOM`, then `DENY`, then `ALLOW`; a `DENY` match ends the decision.
- `spec: {}` allows nothing, `rules: [{}]` allows everything, and a `DENY` with `rules: [{}]` denies everything.
- Use a prefix (`/admin*`) to close a path area, and test a path the rule does not name.
- `DENY` with `notPrincipals: ["*"]` refuses every request without a verified identity.
- Use `ALLOW` policies to describe normal traffic, and a small `DENY` policy as the backstop that no `ALLOW` can reopen.

In short: predict the sidecar proxy's answer from the order, then prove every rule with one request that passes and one that is refused.

<!-- astrona:playground:destroy -->
