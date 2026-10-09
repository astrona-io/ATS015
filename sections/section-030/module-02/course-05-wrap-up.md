# Wrap-Up

You have finished every part and every graded lab in this module. Before you move on, look back at what you learned, check yourself, and remove the playground cleanly.

## What you learned

This module was about reading what a token says, and letting only the right claims through.

**From [Read What The Token Says](./course-01-read-what-the-token-says.md):**

- The JWT filter checks the token (`401` if it is bad) and publishes its claims as `request.auth` attributes. The authorization filter reads them and answers `403` when no rule fits.
- With no `RequestAuthentication` on the workload, no attributes are published, and no claim rule can fit.
- `request.auth.claims[<name>]` reads any claim. A nested claim uses one bracket per level, such as `[realm_access][roles]`.
- `request.auth.principal` is a `when` key; `requestPrincipals` is a `from.source` field. Both match `<iss>/<sub>`.
- Decode a real token (`cut -d. -f2 | base64 -d`) before you name a claim. The two sample tokens have the same principal and different claims.

**From [Require A Claim](./course-02-require-a-claim.md):**

- `when` with `key: request.auth.claims[groups]` and `values: ["group1"]` lets in only tokens whose `groups` contain `group1`.
- Values in one entry are OR. Several entries are AND. A `when` is AND with `from` and `to`. A list claim fits if any item is in `values`.
- A valid token that lacks the claim gets `403`, not `401`, as the `scope3` rule showed.

**From [One Rule Per Role](./course-03-one-rule-per-role.md):**

- Rules in one `ALLOW` policy are OR. A rule with only `to: paths` and no `from` makes a public path.
- One policy per workload, with one rule per role, is the workload's whole access model in one place.
- Pair a claim rule with `requestPrincipals: ["*"]`, so the token requirement is written down.
- A missing claim fails closed under `ALLOW` and open under `DENY`. Write requirements as `ALLOW` rules.

**From [Debug A Claim Rule](./course-04-debug-a-claim-rule.md):**

- A wrong claim name is accepted by Kubernetes and by `istioctl analyze`, and refuses everyone.
- `istioctl proxy-config listener <pod> -o json`, filtered for the keys under `"payload"`, shows the claim names the proxy really compares. No claim name at all means the policy's `selector` reaches no pod.
- Compare the rule from the proxy with the decoded token. That settles it.

## Your graded labs

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Authorize On A JWT Claim](./labs/lab-01/README.md) | One Rule Per Role | open a path to any token and gate an administrator path on a group claim |
| [Fix The Claim Rule](./labs/lab-02/README.md) | Debug A Claim Rule | find a wrong claim name and a public path that needed a token, and fix both |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. A valid token gets <code>403</code>. Another request with a broken token gets <code>401</code>. Which filter answered each one?</summary>

The `401` came from the JWT filter, which the `RequestAuthentication` configures: the token itself is bad. The `403` came from the authorization filter, which the `AuthorizationPolicy` configures: the token was fine, but no rule fit.
</details>

<details>
<summary>2. A token has <code>groups: ["group2", "group3"]</code>. The rule says <code>values: ["group1", "group3"]</code>. Does it fit?</summary>

Yes. Values in one entry are OR, and a list claim fits if any item is in `values`. `group3` is in both.
</details>

<details>
<summary>3. You need a token that is in <code>group1</code> <strong>and</strong> in <code>group2</code>. How do you write it?</summary>

Two `when` entries, one with `values: ["group1"]` and one with `values: ["group2"]`. Entries are combined with AND.
</details>

<details>
<summary>4. A <code>DENY</code> policy has a rule with <code>when: request.auth.claims[groups]</code> and <code>values: ["guest"]</code>, to keep guests out of the administrator path. A token from another system has no <code>groups</code> claim at all. Is it kept out?</summary>

No. A condition on a missing claim does not fit, so the `DENY` rule does not fit, and the request passes. Write the requirement as an `ALLOW` rule with `values: ["admin"]` instead: a missing claim then fails closed.
</details>

<details>
<summary>5. You want <code>/healthz</code> open to everyone and every other path to need a token. How many rules?</summary>

Two rules in one `ALLOW` policy: one with only `to: paths: ["/healthz"]`, and one with `from: requestPrincipals: ["*"]`. Rules are OR. Putting both in one rule would make them AND, and `/healthz` would need a token.
</details>

<details>
<summary>6. A claim rule refuses everyone. <code>istioctl analyze</code> is clean. What do you do next?</summary>

Read the claim names from the proxy with `istioctl proxy-config listener ... -o json` (the keys under `"payload"`), decode a refused token, and compare the claim names letter by letter. If the proxy shows no claim name at all, check the policy's `selector`. Also check that a `RequestAuthentication` selects the workload.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-030-02
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-030-02-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *Read the token, write one `ALLOW` rule per role, and when a claim rule refuses everyone, compare the proxy's rule with the decoded token.*
