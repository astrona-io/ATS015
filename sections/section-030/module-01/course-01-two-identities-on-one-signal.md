# Two Identities On One Signal

Astronaut, one signal can say two different things about who is behind it: which ship sent it, and which person it was sent for. Istio keeps these two apart, with different objects and field names that look alike. This part pulls them apart, opens a real token to see what is inside, and shows where the proxy checks it.

## The ship and the person

Picture an astronaut on board the `bridge` who asks the `probe` for data. Two facts travel with that signal. The ship that sends it is the `bridge`. The person it is sent for is the astronaut. Istio proves each fact in its own way.

### Two kinds of identity

The **peer identity** belongs to the ship (the workload). Ships prove it with the secret handshake of mTLS (mutual TLS): each side shows a certificate before they talk. The **request identity** belongs to the person (the end user). It travels inside the signal as a token, like a boarding pass the astronaut carries.

| | Peer identity (the ship) | Request identity (the person) |
| --- | --- | --- |
| Proved by | a certificate, in the mTLS handshake | a JWT in the `Authorization` header |
| Issued by | `istiod`, automatically | an identity provider outside the mesh (a login service) |
| Checked by | `PeerAuthentication` | `RequestAuthentication` |
| Field in an `AuthorizationPolicy` | `principals` | `requestPrincipals` |
| Looks like | `cluster.local/ns/starfleet/sa/starfleet-bridge` | `<issuer>/<subject>` |
| Travels | one hop: each ship shows its own certificate | end to end: the token is passed on from ship to ship |

The last row explains why both exist. When the `bridge` calls the `scout`, the `scout` sees the **bridge's** certificate, not the astronaut's. The token, in contrast, can be passed on, so a ship three hops away still knows which person the work is for. Neither one can replace the other.

### One rule can ask for both

Both fields sit in the same `from.source` block of an `AuthorizationPolicy` rule. So one rule can demand a certain ship **and** a valid person. You do not apply this yet; just read it:

```yaml
      from:
      - source:
          principals: ["cluster.local/ns/starfleet/sa/starfleet-bridge"]
          requestPrincipals: ["*"]
```

`principals` is the ship's name from its certificate. `requestPrincipals` is the person's name from the token. Mixing up these two fields is the most common reason a rule never matches.

## What is inside a token

A JWT (JSON Web Token) is a boarding pass written as text. Here you open one and read it, because what is inside decides everything the proxy does with it.

### Three parts, joined by dots

A JWT has three parts: `header.payload.signature`. Each part is written in base64url, a way to turn data into plain letters and numbers.

- The **header** says how the token was signed. Its `kid` (key ID) names the key that signed it.
- The **payload** holds the **claims**: the facts written on the pass. `iss` (issuer) is who made the token. `sub` (subject) is who the token is about. `exp` (expiry) is when it stops being valid. `aud` (audience) is who the token is meant for. A token can carry any other claim too, such as `groups`.
- The **signature** proves that the issuer made the token and that nobody changed it.

The issuer signs each token with a secret private key. It then publishes the matching public keys as a **JWKS** (JSON Web Key Set). Think of the JWKS as the list of official stamps: anyone can use it to check that a stamp on a pass is real, but nobody can use it to make a new stamp.

### See it in your playground

You pasted the helpers when you started this module, so `$TOKEN` holds Istio's sample token. If it is empty, paste the helpers again.

<!-- astrona:playground:renew -->

Decode the middle part of the token, the payload:

```sh
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
```

No key was needed. Anyone who holds a token can read every claim in it, so a token never carries secrets. `base64 -d` may complain about missing padding at the end and still print the payload; the `2>/dev/null` hides that complaint. Note `iss` and `sub`: you need both later.

### Signed, not encrypted

Two facts about tokens matter for the rest of this module:

- **The payload is encoded, not encrypted.** Decoding it proves nothing. A fake token decodes just as well as a real one.
- **The signature is what makes the claims worth anything.** When the proxy checks a token, it checks that a key from the issuer's JWKS signed it, and that it has not expired. That is the whole promise: *the issuer said this*.

## The probe is open today

Before you add anything, check the starting point: a ship with no security objects at all, where a token changes nothing because nobody looks at it.

### See it in your playground

List the security objects on the planet, then send 3 signals without a token and 3 with one:

```sh
kubectl get requestauthentication,authorizationpolicy -n starfleet
check_status $PROBE/headers
check_status -H "$AUTH $TOKEN" $PROBE/headers
```

```text
No resources found in starfleet namespace.
200 200 200 
200 200 200 
```

Both get `200`. Nobody checks the pass, so carrying one makes no difference. The rest of this module changes that, one object at a time.

## Where the token is checked

The token is checked by the communications officer of the ship that **receives** the signal, here the probe's sidecar. Inside that proxy, the checks run in a fixed order:

```mermaid
flowchart TB
    S["probe's proxy"] -->|"1. the ship"| P["PeerAuthentication"]
    P -->|"2. the token"| R["RequestAuthentication"]
    R -->|"bad token"| E1["401"]
    R -->|"no token, or valid"| A["AuthorizationPolicy"]
    A -->|"refused"| E2["403"]
    A -->|"allowed"| APP["probe app"]
```

The probe's proxy first checks the ship (the mTLS handshake, set by `PeerAuthentication`), then the person's token (`RequestAuthentication`), and then the guard's list (`AuthorizationPolicy`). Only after all three does the signal reach the app.

Three facts follow from that order, and they are the core of this module:

- **The token check has no opinion about a missing token.** Its job is to check passes. A signal with no `Authorization` header has nothing to check, so it moves on to the guard's list.
- **`401` and `403` come from different steps.** A bad token is stopped by `RequestAuthentication` with `401`. A signal the guard's list refuses is stopped by `AuthorizationPolicy` with `403`. Same signal, two different objects to look at.
- **The token check hands its results to the guard's list.** When a token is valid, `RequestAuthentication` publishes the person's name and claims, and the `AuthorizationPolicy` reads them. Without a valid token, there is nothing to read.

## Common pitfalls

> [!WARNING]
> - **Mixing up the two identities.** The ship's identity comes from its certificate, the person's from a token. `principals` and `requestPrincipals` are different fields.
> - **Trusting a token because it decodes.** Anyone can decode a token, including a fake one. Only the signature check proves anything.
> - **Thinking the token is secret.** A JWT is signed, not encrypted. Every claim in it can be read by anyone who holds it.
> - **Expecting a missing token to be stopped by the token check.** It is not. A signal with no token moves on, and only the guard's list can refuse it.

> *The ship proves who it is with a certificate, one hop at a time; the person proves who they are with a signed token that travels end to end.*
