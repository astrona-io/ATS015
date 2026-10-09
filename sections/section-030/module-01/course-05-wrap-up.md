# Wrap-Up

You have finished every part and every lab in this module. Before you move on, look back at what you learned, check yourself, and remove the playground.

## What you learned

This module was about the end user behind a request: how the proxy checks their token with a `RequestAuthentication`, and how an `AuthorizationPolicy` makes that token required.

**From [Peer Identity And Request Identity](./course-01-two-identities-on-one-signal.md):**

- A request carries two identities. The workload's (peer) identity comes from its mTLS (mutual TLS) certificate and goes in `principals`. The end user's (request) identity comes from a JWT (JSON Web Token) and goes in `requestPrincipals`.
- A JWT has three parts: header, payload and signature. The payload holds the claims, such as `iss`, `sub`, `exp` and `aud`.
- A JWT is signed, not encrypted. Anyone can decode it; only the signature check against the issuer's JWKS (JSON Web Key Set) proves it is valid.
- The receiving workload's sidecar proxy checks in a fixed order: the peer (mTLS), then the token, then the `AuthorizationPolicy`.

**From [Check The Token With RequestAuthentication](./course-02-check-the-token.md):**

- A `RequestAuthentication` checks a token if one is there. A bad token gets `401`. A request **without** a token still gets in.
- `issuer` must match the token's `iss` claim letter for letter. `jwksUri` is where the public keys live; `jwks` puts them in the object instead.
- `istiod`, the control plane, downloads the keys and sends them to the proxy. If it cannot reach `jwksUri`, every token gets `401`, even good ones.
- `audiences` is only checked when you set it. Without `forwardOriginalToken: true`, the proxy removes the `Authorization` header before the app sees it.
- `istioctl proxy-config listener` shows the `jwt_authn` filter and the exact `issuer` the proxy compares.

**From [Require A Token](./course-03-require-a-token.md):**

- An `ALLOW` policy with `requestPrincipals: ["*"]` requires a valid token. A request without one has no request principal, so it gets `403`.
- A request principal is `<iss>/<sub>`. `["*"]` is any valid token; `issuer/*` is anyone from one issuer.
- `401` with `Jwt ...` comes from the `RequestAuthentication`: look at the token, the issuer and the keys. `403` with `RBAC: access denied` comes from the `AuthorizationPolicy`: look at the policy.
- Apply the `RequestAuthentication` first, then the policy. In the other order, every request is refused. Remove them in the reverse order.

**From [Other Token Places And The DENY Form](./course-04-other-token-places-and-deny.md):**

- `fromParams` and `fromHeaders` move the token to a query parameter or another header. Once set, the `Authorization` header is no longer read, so a token there gets `403`.
- `DENY` with `notRequestPrincipals: ["*"]` also requires a token, with the same codes.
- A `DENY` policy does not switch the workload to "only what a rule allows", so it can sit on top of other policies safely.

## Your labs

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Require A Valid End-User Token](./labs/lab-01/README.md) | Require A Token | check tokens on one service, require one, and keep its neighbour open |
| [Read A JWT From A Query Parameter](./labs/lab-02/README.md) | Other Token Places And The DENY Form | read the token from a query parameter and require it with a `DENY` policy |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You apply only a <code>RequestAuthentication</code>. A request with no token arrives. What happens?</summary>

It gets in with `200`. A `RequestAuthentication` checks tokens that are there; it never requires one. You need an `AuthorizationPolicy` with `requestPrincipals` (or `DENY` with `notRequestPrincipals`) to refuse it.
</details>

<details>
<summary>2. A request gets <code>401</code>. Which object refused it, and what do you check?</summary>

The `RequestAuthentication`. A token was there and failed the check. Check the token (expired?), the `issuer` against the token's `iss`, and whether `istiod` could download the keys from `jwksUri`.
</details>

<details>
<summary>3. A request gets <code>403</code> with <code>RBAC: access denied</code>. Is the token bad?</summary>

No. `403` comes from the `AuthorizationPolicy`. The token was valid, or there was no token at all, and the rule did not match. Read the policy: the `requestPrincipals` value and the `selector`.
</details>

<details>
<summary>4. Every token gets <code>401</code>, including the sample token that worked yesterday. The object looks right. What are the two likely causes?</summary>

The `issuer` does not match `iss` exactly (for example a trailing slash), or `istiod` cannot reach `jwksUri`, so the proxy has no keys. Compare the issuer from `istioctl proxy-config listener` with the decoded token, and read the `istiod` log.
</details>

<details>
<summary>5. You apply the policy with <code>requestPrincipals: ["*"]</code> before the <code>RequestAuthentication</code>. What do requests with a valid token get?</summary>

`403`. No token is checked yet, so no request has a request principal, and the `ALLOW` rule matches nothing. Apply the `RequestAuthentication` first.
</details>

<details>
<summary>6. What is the request principal of a token with <code>iss: testing@secure.istio.io</code> and <code>sub: alice</code>?</summary>

`testing@secure.istio.io/alice`: the issuer, a slash, and the subject.
</details>

<details>
<summary>7. The <code>RequestAuthentication</code> has <code>fromParams: [token]</code>. A client sends a valid token in <code>Authorization: Bearer</code>, and a policy requires a token. What does it get, and why?</summary>

`403`. With `fromParams` set, the proxy reads only the query parameter. It sees no token, attaches no request principal, and the policy refuses the request. It is not `401`, because no token was read and found invalid.
</details>

<details>
<summary>8. What is the difference between "token required" as <code>ALLOW</code> with <code>requestPrincipals: ["*"]</code> and as <code>DENY</code> with <code>notRequestPrincipals: ["*"]</code>?</summary>

The codes are the same. But the `ALLOW` form switches the workload to "only what a rule allows", so anything no `ALLOW` rule matches is refused. The `DENY` form only refuses requests without a token, and leaves every other rule as it was.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-030-01
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-030-01-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *A `RequestAuthentication` validates the token; an `AuthorizationPolicy` decides which requests must carry one. Protecting a workload always takes both.*
