---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` has sidecar injection on and a `PeerAuthentication` in `STRICT` mode. It runs:

* `probe`: an HTTP echo server with the label `app: probe`, Service port `8000`. `/headers` echoes the request headers and `/ip` returns the caller's address.
* `ext-authz`: the Istio sample external authorizer, Service `ext-authz` with HTTP on port `8000` and gRPC on port `9000`. It allows a check request only if the header `x-ext-authz: allow` is present. Its pod has no sidecar.
* `shuttle`: a client pod with `curl`, service account `shuttle`.

Istio 1.30.5 is installed. No extension provider and no `AuthorizationPolicy` exists yet.

1. **Register** the HTTP authorizer as an extension provider named `starfleet-authz` in the mesh configuration. Keep every setting that is already in the mesh configuration. The provider must send the header `x-ext-authz` to the authorizer.
2. **Create** a `CUSTOM` `AuthorizationPolicy` in `starfleet` that selects the `probe` and sends only requests for the path `/headers` to `starfleet-authz`.

The result, with each request sent from the `shuttle` to `http://probe:8000`:

| Request | Expected status |
| --- | --- |
| `/headers`, no extra header | `403` |
| `/headers`, header `x-ext-authz: deny` | `403` |
| `/headers`, header `x-ext-authz: allow` | `200` |
| `/ip`, no extra header | `200` |

Constraints:

* Do not change the Deployments, Services or the `PeerAuthentication`.
* Do not add an `ALLOW` or `DENY` policy.
* Do not remove other settings from the mesh configuration.

The grader reads the mesh configuration and the policy, then sends the four requests, so the setup has to work, not merely exist.
