# Summary

The `CUSTOM` action moves an authorization decision out of Istio and into an external authorizer. The sidecar proxy of the protected workload pauses each request that matches a rule of the policy, sends a check request to the authorizer, and forwards or rejects the request by the answer. The caller's sidecar takes no part.

An authorizer is registered as an extension provider in the mesh configuration, under `meshConfig.extensionProviders`. With the Helm install, `istiod` reads that block from the key `mesh` in the ConfigMap `istio` in `istio-system`. The type `envoyExtAuthzHttp` calls the authorizer over HTTP and sends only the headers named in `includeRequestHeadersInCheck`. The type `envoyExtAuthzGrpc` calls the Envoy gRPC service. A `CUSTOM` policy refers to the provider by `provider.name`, and its rules choose which requests are checked.

`CUSTOM` is evaluated first, then `DENY`, then `ALLOW`. An authorizer allow is not final: a `DENY` match or a missing `ALLOW` match still rejects the request. When the authorizer is unreachable, the default `failOpen: false` rejects the request with status `403`.

The key facts to remember are these:

- Provider definition goes in the mesh configuration. The policy only names it.
- Only requests that match a `CUSTOM` rule are sent to the authorizer.
- Order: `CUSTOM`, `DENY`, `ALLOW`.
- Defaults: `failOpen: false`, `statusOnError: 403`, `timeout: 600s`.
- Patch the `mesh` key by appending to its current value, never by replacing it.

In short: register the provider, scope the `CUSTOM` rule to the paths that need the check, and test one request that the authorizer allows, one it denies and one that is never sent to it.

<!-- astrona:playground:destroy -->
