# Authorize HTTP Traffic Between Workloads

Mutual TLS (mTLS) is already in place. With mTLS, both sides of a connection present a certificate, so every workload in the namespace knows **who** is calling. But knowing who is calling is not the same as letting the caller in. Right now any workload with a valid certificate may send any request to any other workload.

This module adds authorization to each workload. You set it with an `AuthorizationPolicy`: an Istio object that allows or denies requests to a workload, based on who sends them, what they ask for and extra conditions. You will close a whole namespace with one empty policy, then open exactly the calls the application needs, and nothing more. On the exam you write these policies by hand on a live cluster, and you prove each one with a request that gets in and a request that is denied.

The surprising part is not a field at all. With no policy, the sidecar proxy lets every request in. The moment the first `ALLOW` policy selects a workload, that workload turns strict, and the proxy refuses every request the policy does not name.

The module takes you there in six parts. **Where Authorization Is Enforced** shows where the decision is made, which component makes it, and why a workload with no policy lets every request in. **Deny By Default With An Allow-Nothing Policy** closes the namespace and explains why `spec: {}` and `rules: [{}]` do opposite things. **Write An ALLOW Rule** takes a rule apart into `from`, `to` and `when`, and shows how those parts combine and how paths match.

The second half builds on that. **Match The Caller By Identity** narrows a rule to one caller with `principals` and `namespaces`, and shows what happens when several `ALLOW` policies select one workload. **Least Privilege For Every Service** gives each workload of the sample application its own policy. **Troubleshoot An Authorization Denial** uses the access log, the proxy's configuration and `istioctl analyze` to tell a wrong rule from a policy that never arrived. A short summary closes the module, and two graded labs test what you learned along the way.

## Learning objectives

After this module you can:

- Name the component that enforces authorization, say on which side of the request it runs, and explain why the caller learns almost nothing from a denial.
- Explain what an `AuthorizationPolicy` with an empty `spec: {}` does, field by field, and why it is the usual deny-by-default starting point.
- State the rule that creates default-deny, and predict what a workload with no policy allows.
- Tell `spec: {}` (allow nothing) apart from `rules: [{}]` (allow everything).
- Write `ALLOW` rules on `from.source`, `to.operation` and `when`, and say how values, fields, parts and rules combine.
- Write a `principals` rule from a workload's service account, and explain why it needs mTLS to match.
- Predict the result when two `ALLOW` policies select the same workload.
- Give every service of an application its own least-privilege policy.
- Tell an authorization denial (`403`) apart from a transport rejection, and a wrong rule apart from a policy that never reached the proxy.

## Before you start

This module builds on workload identity. `istiod`, Istio's control plane, gives every pod with a sidecar a certificate. The name in that certificate is the SPIFFE ID. It comes from the pod's namespace and service account, and it looks like `spiffe://cluster.local/ns/starfleet/sa/shuttle`.

You should also know `PeerAuthentication`, the Istio object that sets whether a workload accepts plain text, mTLS or both. In `STRICT` mode, a workload accepts only mTLS connections, so a caller with no sidecar is cut off before any other check runs. Beyond that, you need Kubernetes basics: namespaces, Deployments, Services, service accounts, pod labels and `kubectl exec`.

Your playground is one `kind` cluster with **Istio 1.30.5** already installed, and two namespaces.

| Namespace | Workload | Service account | What it does |
| --- | --- | --- | --- |
| `starfleet` | `bridge` | `starfleet-bridge` | Web frontend; it calls `cargo` and `scout` |
| `starfleet` | `cargo` | `starfleet-cargo` | Backend that returns item details |
| `starfleet` | `scout` v1, v2, v3 | `starfleet-scout` | Backend in three versions; v2 and v3 call `navcom` for star ratings |
| `starfleet` | `navcom` | `starfleet-navcom` | Backend that returns the star rating |
| `starfleet` | `shuttle` | `shuttle` | Test client: most test requests are sent from here |
| `starfleet` | `fortio` | `default` | A second client with another identity |
| `starfleet` | `probe` v1, v2 | `probe` | HTTP echo server on port `8000`: it sends back what it receives |
| `outpost` | `drifter` | (none) | A client pod with no sidecar and no certificate |

Every pod in `starfleet` shows `2/2`: the app container plus the `istio-proxy` sidecar. The sidecar proxy (Envoy) is a proxy container that Istio adds to each pod; all inbound and outbound traffic of the pod passes through it.

The namespace already has a **`PeerAuthentication` in `STRICT` mode**. That is the starting condition, not the subject, because identity rules need a verified certificate. There is **no** `AuthorizationPolicy` yet, so every request that passes mTLS gets in. You can also watch the `bridge` page in your browser at `http://127.0.0.1:9080/productpage`. It breaks and comes back as you add policies.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Once it runs, paste three small helper functions into each new terminal. Every part uses them to send test requests, and each comment says what the helper does:

```sh
# 3 requests from the shuttle (service account shuttle); prints each status code
from_shuttle() { for i in 1 2 3; do kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"; done; echo "<- $*"; }
# 1 request from fortio (service account default); prints the status code
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
# 1 request from the drifter in the outpost namespace (no sidecar, no identity); prints the status code
from_drifter() { kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" "$@"; }
```

Use them like this: `from_shuttle http://probe:8000/get`, `from_fortio http://probe:8000/get`, and `from_drifter http://probe.starfleet:8000/get`. The drifter runs in another namespace, so its address needs the namespace.
