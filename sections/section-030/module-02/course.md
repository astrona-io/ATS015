# Authorize On JWT Claims

Astronaut, a valid token is a low bar. Every logged-in crew member has one, including the ones who should never open the admin hatch. Real access control asks what the token **says**: which user, in which groups, with which permissions.

A JWT (JSON Web Token) is a signed boarding pass that an astronaut carries with every signal. The agency that printed it, the **issuer**, signs it, so nobody can change it. The lines printed on the pass are called **claims**: who you are, which crew you belong to, which clearance you have.

The `RequestAuthentication` is the pass checker: it checks any pass that is shown. Once it has checked a token, Istio hands the claims to the `AuthorizationPolicy`, the guard's list at the airlock. The guard can then say "only crew in `group1` may come aboard". That hand-off is the whole idea. The rest of this module is the syntax, and the few ways it fails without any error.

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

Every mission starts with a pre-flight check. Make sure you know the basics below, know what is waiting in your playground, and have the helpers ready in your terminal.

### What you should already know

- **`AuthorizationPolicy` basics.** A policy has a `selector`, an `action` (`ALLOW` or `DENY`) and `rules` with `from`, `to` and `when`. Rules in one policy are combined with OR. The parts inside one rule are combined with AND.
- **`RequestAuthentication` basics.** It checks a token **if one is present**, and answers `401` for a bad token. On its own it does not require a token. `requestPrincipals: ["*"]` in an `AuthorizationPolicy` is what makes a token required, and a refused request gets `403`.
- **Kubernetes basics.** Namespaces, Deployments, Services, pod labels and `kubectl exec`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** already installed. Everything you need is on one planet, the namespace **`starfleet`**.

| Ship | Its role in this module |
| --- | --- |
| `probe` v1, v2 | The **echo probe**, behind one Service on port `8000`. It sends back what it receives. Every claim rule in this module protects it |
| `shuttle` | **Your shuttle**. You send every test signal from here, with the `curl` command |
| `bridge`, `cargo`, `scout`, `navcom` | The rest of the Starfleet. This module does not use them |

Every pod shows `2/2`: the app plus its communications officer (the `istio-proxy` sidecar).

One object is already in place: a `RequestAuthentication` named `probe-jwt`. It tells the probe's communications officer to check tokens from Istio's sample issuer, `testing@secure.istio.io`. It is a starting point, not the subject of this module. There is **no** `AuthorizationPolicy` yet, so tokens are checked but none is required.

The playground needs internet access. Mission control (`istiod`) downloads the issuer's public keys, and you download two sample tokens.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Helpers to paste first

Paste this into each new terminal before you start. It downloads Istio's two sample tokens and defines `check_status`, which sends 3 signals from the shuttle and prints each status code:

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

Use it like this: `check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers`. Any `curl` options you add are passed on.

## The parts, in order

1. [Read What The Token Says](./course-01-read-what-the-token-says.md): what a checked token hands to authorization, the attribute names, and why you decode a real token first.
2. [Require A Claim](./course-02-require-a-claim.md): the `when` block, list claims, and how values and entries combine.
3. [One Rule Per Role](./course-03-one-rule-per-role.md): a public path, a token path and a group path in one policy, and what a missing claim does under `ALLOW` and `DENY`. Ends with a graded mission.
4. [Debug A Claim Rule](./course-04-debug-a-claim-rule.md): find out why a correct-looking claim rule refuses everyone. Ends with a graded mission.
5. [Wrap-Up](./course-05-wrap-up.md): what you learned, your missions, and cleaning up.

## Why this matters

On the exam you write claim rules by hand and prove them with real requests. Most mistakes compile cleanly and fail quietly: a claim name that no token has, a requirement put in a `DENY`, a public path that is not public. This module trains you to read the token, write the rule, and check what the proxy really holds.
