# Authenticate End Users With JWT

Astronaut, until now every check in the mesh was about **ships**: which spaceship (pod) sends a signal, proved by the secret handshake of mTLS (mutual TLS). But most signals carry a second identity too: the **person** the signal is sent for. That one does not come from a certificate. It arrives as a **JWT** (JSON Web Token), a signed boarding pass inside the signal's `Authorization` header.

Istio checks the boarding pass with one object and decides who may come aboard with another. The surprise of this module is not the YAML. It is a behaviour: a `RequestAuthentication` checks a pass **if one is shown**, and does nothing at all about a signal that carries no pass. So protecting a ship always takes two objects, and knowing which one does what is most of this module.

## Learning objectives

After this module you can:

- Tell the ship's identity (peer identity) from the person's identity (request identity), and name the object and the policy field for each.
- Name the three parts of a JWT, read its claims, and say which part the proxy checks.
- Write a `RequestAuthentication` with an `issuer` and a `jwksUri`, and explain how the signing keys reach the proxy.
- Explain why a `RequestAuthentication` alone protects nothing, and require a token with `requestPrincipals` in an `AuthorizationPolicy`.
- Tell `401` from `403`, and say which object sent each one.
- Apply the two objects in the safe order, and remove them in the reverse order.
- Read the token from a query parameter with `fromParams`, and write "token required" as a `DENY` policy with `notRequestPrincipals`.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you know what this module expects, what is waiting in your playground, and have the helpers ready in your terminal.

### What you should already know

- **How the mesh works.** A proxy sits beside every pod. Think of it as the ship's communications officer: every signal in or out goes through them. `istiod` is mission control: it sends every communications officer their orders.
- **`AuthorizationPolicy` basics.** An `AuthorizationPolicy` is a guard's list for a ship. It has a `selector` (which ships), an `action` (`ALLOW` or `DENY`) and `rules` (who matches). Once an `ALLOW` policy selects a ship, that ship lets in only what the list allows and refuses everything else.
- **Kubernetes basics.** Namespaces, Deployments, Services, pod labels and `kubectl exec`.

You do not need to know how tokens are signed. You need to know that a token is a string with three parts, joined by dots, and that a signature can be checked with a public key.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5** already installed. Everything is on one planet, the namespace **`starfleet`**:

| Ship | Its role in this module |
| --- | --- |
| `probe` v1, v2 | The **echo probe**: it sends back what it receives. This is the ship you protect with a token. `/headers` shows which headers reached it |
| `shuttle` | **Your shuttle**. You send every test signal from here, with the `curl` command |
| `bridge`, `cargo`, `scout`, `navcom` | The rest of the Starfleet. Nothing in this module protects them, so they show that your rules stay on the probe |

Every pod shows `2/2`: the app plus its communications officer (the `istio-proxy` sidecar). There is **no** `RequestAuthentication` and **no** `AuthorizationPolicy` yet.

This module needs **outbound internet** from your machine and from the cluster. You download Istio's sample token, and `istiod` downloads the matching signing keys, both from `raw.githubusercontent.com`. Without it, every token is rejected and nothing in this module behaves as described.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### The helpers to paste first

Paste this into each new terminal before you start. It downloads the sample token into `$TOKEN` and defines `check_status`, which sends 3 signals from the shuttle and prints the status code of each:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

Use it like this: `check_status $PROBE/headers` for a signal with no token, or `check_status -H "$AUTH $TOKEN" $PROBE/headers` for a signal with the token. Any `curl` options you add are passed on.

## The parts of this module

Read the parts in this order. Each one ends with something you have seen work in your playground.

1. [Two Identities On One Signal](./course-01-two-identities-on-one-signal.md): the ship's identity and the person's identity, what is inside a token, and where the proxy checks it.
2. [Check The Token With RequestAuthentication](./course-02-check-the-token.md): `issuer`, `jwksUri`, how the keys reach the proxy, and why a signal without a token still gets in.
3. [Require A Token](./course-03-require-a-token.md): `requestPrincipals`, `401` versus `403`, and the safe order to apply things. Then your first mission.
4. [Other Token Places And The DENY Form](./course-04-other-token-places-and-deny.md): a token in a query parameter, and "token required" written as `DENY`. Then your second mission.
5. [Wrap-Up](./course-05-wrap-up.md): what you learned, your missions, questions to check yourself, and cleaning up.

## Why this matters

On the exam you write security objects by hand on a live cluster and prove they work. "Only signals with a valid token may reach this service" is one of the most common tasks, and the most common wrong answer is a `RequestAuthentication` on its own. It is accepted, it looks right, and it lets every signal without a token straight through. After this module you will see that gap at once, and the status code will tell you which object to fix.
