# Summary

A TCP workload is protected by the same `AuthorizationPolicy` object as an HTTP workload, but the sidecar proxy sees a connection and not a request. The proxy can read the destination port, the caller's address and, with mutual TLS, the caller's identity and namespace. It cannot read a method, a path or a header.

Because identity comes from the certificate, `principals` and `namespaces` need mTLS. A `STRICT` `PeerAuthentication` closes the connection of a caller without a certificate before any rule runs. An `ALLOW` policy that names ports and principals limits a workload to named callers on named ports. It also closes every port the policy does not name, including a port that the Kubernetes Service does not list and that is reachable only by pod IP.

HTTP-only fields behave differently under each action. An `ALLOW` rule that uses `hosts`, `methods` or `paths` on TCP is invalid and ignored, so the workload falls back to default-deny and refuses everything. A `DENY` rule treats a missing attribute as a match, so a `DENY` with only an HTTP-only field denies all TCP traffic to the workload. The same field next to a `ports` value matches only that port.

The key facts to remember are these:

- Fields that work on TCP: `principals`, `namespaces`, `ipBlocks` and `ports`, with their negative forms.
- `hosts`, `methods` and `paths` apply to HTTP only.
- One `ALLOW` policy on a workload refuses every connection that no rule matches, on every port.
- A TCP refusal has no status code: the caller sees a closed connection.
- Scope every `DENY` rule on a TCP workload with `ports`.

In short: on TCP, write rules with connection fields only, and prove each policy with a connection that passes and one that is refused.

<!-- astrona:playground:destroy -->
