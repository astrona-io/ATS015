# Authenticate End Users With JWT

Until now every check in the mesh was about **workloads**: which pod sends a request, proved by mTLS (mutual TLS, where both sides present a certificate, so the connection is encrypted and both identities are verified). But most requests carry a second identity too: the **end user** the request is sent for. That identity does not come from a certificate. It arrives as a **JWT** (JSON Web Token), a signed token that carries claims about the end user, inside the request's `Authorization` header.

Istio validates the token with one object and decides which requests are allowed with another. The surprise here is not the YAML. It is a behaviour: a `RequestAuthentication` validates a token **if the request carries one**, and does nothing at all about a request without a token. So protecting a workload always takes two objects, and knowing which one does what is most of this module.

This matters on the exam. "Only requests with a valid token may reach this service" is one of the most common tasks, and the most common wrong answer is a `RequestAuthentication` on its own. It is accepted, it looks right, and it lets every request without a token straight through.

The module follows one workload, the `probe`, from open to protected, in four parts. **Peer Identity And Request Identity** separates the workload's identity from the end user's, decodes a real token, and shows where the proxy checks it. **Check The Token With RequestAuthentication** adds the token check and explains `issuer`, `jwksUri` and how the keys reach the proxy. **Require A Token** closes the gap with an `AuthorizationPolicy` and shows how `401` and `403` point at different objects. **Other Token Places And The DENY Form** reads the token from a query parameter and writes "token required" as a `DENY` policy.

## Learning objectives

After this module you can:

- Tell the workload's identity (peer identity) from the end user's identity (request identity), and name the object and the policy field for each.
- Name the three parts of a JWT, read its claims, and say which part the proxy checks.
- Write a `RequestAuthentication` with an `issuer` and a `jwksUri`, and explain how the signing keys reach the proxy.
- Explain why a `RequestAuthentication` alone protects nothing, and require a token with `requestPrincipals` in an `AuthorizationPolicy`.
- Tell `401` from `403`, and say which object sent each one.
- Apply the two objects in the safe order, and remove them in the reverse order.
- Read the token from a query parameter with `fromParams`, and write "token required" as a `DENY` policy with `notRequestPrincipals`.

## Before you start

You need Kubernetes basics: namespaces, Deployments, Services, pod labels and `kubectl exec`. You also need a rough picture of the mesh. Istio adds a sidecar proxy (Envoy) to every pod: a proxy container that all inbound and outbound traffic of the pod passes through. `istiod` is Istio's control plane: it sends configuration and certificates to every proxy.

You should also know the basics of an `AuthorizationPolicy`, the object that allows or denies requests to a workload. It has a `selector` (which workloads), an `action` (`ALLOW` or `DENY`) and `rules` (which requests match). Once an `ALLOW` policy selects a workload, that workload accepts only the requests the rules allow and refuses everything else. You do not need to know how tokens are signed. It is enough to know that a token is a string with three parts, joined by dots, and that a signature can be checked with a public key.

Your playground is one `kind` cluster with **Istio 1.30.5** already installed. Everything runs in one namespace, **`starfleet`**:

| Workload | Its role in this module |
| --- | --- |
| `probe` v1, v2 | An HTTP echo server: it sends back what it receives. This is the workload you protect with a token. `/headers` shows which headers reached it |
| `shuttle` | Test client pod. You send every test request from here, with the `curl` command |
| `bridge`, `cargo`, `scout`, `navcom` | The rest of the sample app. Nothing in this module protects them, so they show that your rules stay on the probe |

Every pod shows `2/2`: the app container plus the `istio-proxy` sidecar. There is **no** `RequestAuthentication` and **no** `AuthorizationPolicy` yet.

This module needs **outbound internet** from your machine and from the cluster. You download Istio's sample token, and `istiod` downloads the matching signing keys, both from `raw.githubusercontent.com`. Without it, every token is rejected and nothing in this module behaves as described.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Once it runs, paste the helpers below into each new terminal. They download the sample token into `$TOKEN` and define `check_status`, which sends 3 requests from the `shuttle` pod and prints the status code of each:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

Use it like this: `check_status $PROBE/headers` for a request with no token, or `check_status -H "$AUTH $TOKEN" $PROBE/headers` for a request with the token. Any `curl` options you add are passed on.
