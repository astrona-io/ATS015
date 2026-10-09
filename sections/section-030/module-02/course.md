# Authorize On JWT Claims

A valid token is a low bar. Every logged-in user has one, including the users who should never reach an administrator path. Real access control asks what the token **says**: which user, in which groups, with which permissions.

A JWT (JSON Web Token) is a signed token that a client sends with each request, usually in the `Authorization` header. The system that creates it, the **issuer**, signs it, so nobody can change it without breaking the signature. The fields inside the token are called **claims**. They say who the user is, which groups the user belongs to and which permissions the user has.

Two Istio objects work together on these claims. A `RequestAuthentication` tells the sidecar proxy to validate any token a request carries. Once the proxy has validated a token, it passes the claims on to the `AuthorizationPolicy`, the object that allows or denies requests to a workload. The policy can then say "only users in `group1` may reach this path".

That hand-off is the whole idea, and this module follows it in four parts. **Read What The Token Says** shows what a checked token hands to authorization, what each fact is called, and why you decode a real token first. **Require A Claim** writes the first `when` condition and explains how values and entries combine. **One Rule Per Role** builds a public path, a token path and a group path into one policy, and shows what a missing claim does under `ALLOW` and `DENY`. **Debug A Claim Rule** finds out why a correct-looking claim rule refuses everyone.

On the exam you write claim rules by hand and prove them with real requests. Most mistakes compile cleanly and fail quietly: a claim name that no token has, a requirement put in a `DENY`, a public path that is not public. So this module trains three habits: read the token, write the rule, and check what the proxy really holds.

## Learning objectives

After this module you can:

- Name the request attributes a checked token gives you, such as `request.auth.principal` and `request.auth.claims[groups]`.
- Decode a token and read the real claim names before you write a rule.
- Write a `when` condition on a single-value claim and on a list claim such as `groups`.
- Say whether two `when` entries, and two values in one entry, are combined with AND or with OR.
- Predict what a missing claim does under `ALLOW` and under `DENY`.
- Build one policy with one rule per role, including a public path that needs no token.
- Tell a wrong claim name from a policy that never reached the proxy, and fix it.

## Before you start

You need the basics of an `AuthorizationPolicy`. A policy has a `selector`, an `action` (`ALLOW` or `DENY`) and `rules` with `from`, `to` and `when`. Rules in one policy are combined with OR, and the parts inside one rule are combined with AND.

You also need the basics of a `RequestAuthentication`. It checks a token **if one is present**, and it answers `401` for a bad token. On its own it does not require a token. The setting `requestPrincipals: ["*"]` in an `AuthorizationPolicy` is what makes a token required, and a request it refuses gets `403`. Finally, you need Kubernetes basics: namespaces, Deployments, Services, pod labels and `kubectl exec`.

Your playground is one `kind` cluster with **Istio 1.30.5** already installed. Everything you need is in one namespace, **`starfleet`**:

| Workload | Its role in this module |
| --- | --- |
| `probe` v1, v2 | An HTTP echo server, behind one Service on port `8000`. It sends back what it receives. Every claim rule in this module protects it |
| `shuttle` | Your test client pod. You send every test request from here, with the `curl` command |
| `bridge`, `cargo`, `scout`, `navcom` | The rest of the sample app. This module does not use them |

Every pod shows `2/2`: the app plus its sidecar proxy, the `istio-proxy` container. The sidecar proxy is an Envoy proxy that Istio adds to each pod; all inbound and outbound traffic of the pod passes through it.

One object is already in place: a `RequestAuthentication` named `probe-jwt`. It tells the probe's sidecar proxy to validate tokens from Istio's sample issuer, `testing@secure.istio.io`. It is a starting point, not the subject of this module. There is **no** `AuthorizationPolicy` yet, so the proxy checks tokens but does not require one.

The playground needs internet access for two reasons. `istiod`, Istio's control plane, downloads the issuer's public keys, and you download two sample tokens.

Start your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Every part sends its test requests with the same few shell helpers. Paste them into each new terminal before you start. They download Istio's two sample tokens and define `check_status`, which sends 3 requests from the `shuttle` pod and prints each status code:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
GROUPS_TOKEN=$(curl -s $SAMPLES_URL/groups-scope.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

You use it like this: `check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers`. Any `curl` options you add are passed on.
