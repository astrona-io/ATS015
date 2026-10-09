# Summary

mTLS tells a workload who is calling. Authorization decides whether that caller may get in. This module covered one object, the `AuthorizationPolicy`, from where its check runs, to how its rules combine, to how you find out why it said no.

## What you learned

Authorization runs in the sidecar proxy of the pod that **receives** the request, as Envoy's RBAC (role-based access control) filter. `istiod` compiles each policy into that filter, but only for the pods its `selector` matches. The receiving proxy checks mTLS first, then reads the HTTP request, then runs the JWT check, and only then runs authorization. So a cut connection (`000`, curl exit code `56`) comes from the mTLS check, while a denied request gets a full `403` with the body `RBAC: access denied`.

With no policy selecting a workload, every request that passes mTLS gets in. The first `ALLOW` policy that selects a workload is what makes it deny by default. An empty `spec: {}` is an `ALLOW` policy for the whole namespace with no rules, so it allows nothing. One empty rule, `rules: [{}]`, does the opposite and allows everything. The usual pattern is one allow-nothing policy per namespace, plus narrow `ALLOW` policies per workload.

A rule has up to three parts: `from` (who), `to` (which operation) and `when` (extra conditions). Values in one field combine with OR, fields and parts with AND, and rules and policies with OR. A part you leave out is a wildcard, not a limit. Paths match exactly, by prefix or by suffix, with no regular expression.

A `principals` rule names a caller by the identity in its certificate, which comes from the pod's namespace and service account. Both `principals` and `namespaces` need mTLS, because without a verified certificate there is no identity to match. Least privilege turns a map of who calls whom into one policy per workload, with one rule per call.

When a policy seems to do nothing, it either never reached the proxy or arrived with a rule that does not match. The proxy's configuration shows which policies arrived, `istioctl analyze` flags a selector that matches no pod, and the receiver's access log shows which policy decided. The key facts to remember are these:

- `principals` takes the name **without** `spiffe://`, for example `cluster.local/ns/starfleet/sa/shuttle`.
- `ALLOW` policies on one workload add up, so another `ALLOW` policy can only let more in. To take something away, you need `DENY`, which the proxy checks first.
- A policy with no selector covers its own namespace, or the whole mesh when it lives in the root namespace `istio-system`.
- `rbac_access_denied_matched_policy[none]` in the receiver's access log means no `ALLOW` rule matched.
- Apply narrow policies first and the allow-nothing policy last.

In short: the first `ALLOW` closes the workload, every `ALLOW` adds to what gets in, and each caller is named by the identity that mTLS verified.

<!-- astrona:playground:destroy -->
