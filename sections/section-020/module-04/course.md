# External Authorization With CUSTOM Policies

An `AuthorizationPolicy` with the action `ALLOW` or `DENY` decides from fields that the sidecar proxy can read itself: the caller's identity, the source address, the port, the method, the path and request headers. Some decisions need more than that. A company may keep access rules in its own service, check a session token against a database, or call a policy engine. Writing those rules as `AuthorizationPolicy` fields is not possible.

The `CUSTOM` action solves this. The sidecar proxy (Envoy), the proxy container Istio adds to each pod, pauses the request and asks an **external authorizer**, a service that you run, whether the request may continue. The authorizer answers allow or deny. Istio does not know the rules the authorizer uses. It only knows where the authorizer is and which requests to send to it.

This module answers the question in three parts. **Where The Decision Is Made** explains what the sidecar sends to the authorizer, what comes back, and how a `CUSTOM` policy fits in the evaluation order. **Register A Provider And Attach It** adds the authorizer to the mesh configuration and attaches it to one path of a workload. **CUSTOM With ALLOW And DENY** shows how a `CUSTOM` policy combines with the other two actions and what happens when the authorizer is not reachable. A short summary closes the module.

## Learning objectives

After this module you can:

- Describe what the sidecar proxy sends to an external authorizer and what it does with the answer.
- Register an HTTP or gRPC authorizer as an extension provider in the mesh configuration.
- Write a `CUSTOM` policy that sends only selected requests to the provider.
- State the evaluation order of `CUSTOM`, `DENY` and `ALLOW` policies.
- Predict the result when the authorizer is down.

## Before you start

You need the parts of an `AuthorizationPolicy`. A `selector` picks the pods the policy protects. The `action` says what to do on a match. The `rules` hold the conditions. A rule with `to.operation.paths` matches the request path. You also need to know that the mesh configuration (`meshConfig`) is the set of mesh-wide options of Istio. With the Helm install used here, `istiod` (the Istio control plane) reads it from a ConfigMap named `istio` in the namespace `istio-system`, under the key `mesh`.

Your playground is a `kind` cluster with **Istio 1.30.5** installed with Helm. You work in the namespace **`starfleet`**:

| Workload | Its role in this module |
| --- | --- |
| `probe` | **The protected workload.** An HTTP echo server on port `8000`. `/headers` echoes the request headers, `/ip` returns the caller's address |
| `ext-authz` | **The external authorizer.** The Istio sample authorizer. It listens for HTTP on port `8000` and for gRPC on port `9000`. It allows a check request only if the header `x-ext-authz: allow` is present. Its pod has no sidecar |
| `shuttle` | The client. Identity `cluster.local/ns/starfleet/sa/shuttle` |
| `fortio` | A second client with a different identity |

A `PeerAuthentication` in `STRICT` mode is in place in `starfleet`. There is **no extension provider and no `AuthorizationPolicy` yet**.

Launch your playground now and keep it running while you read:

<!-- astrona:playground -->

## Helpers for your terminal

Paste this into each new terminal. It sends one request from the shuttle and prints the status code:

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -c shuttle -- curl -s -o /dev/null -w "%{http_code}\n" "$@"; }
PROBE=http://probe:8000
```

`from_shuttle $PROBE/headers` prints one status code. Extra `curl` options are passed on: `from_shuttle -H "x-ext-authz: allow" $PROBE/headers`. After every `kubectl apply` or ConfigMap change, wait up to about a minute before you trust a test.
