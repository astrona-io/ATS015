# Wrap-Up

You have finished every part and every lab in this module. Before you move on, look back at what you learned, check yourself, and clean up the playground.

## What you learned

This module was about `action: DENY`, and the fixed order in which the sidecar proxy of the receiving pod checks `AuthorizationPolicy` resources.

**From [DENY Is Checked Before ALLOW](./course-01-the-guard-checks-the-banned-list-first.md):**

- The check runs in the sidecar proxy of the pod that **receives** the request. It checks `CUSTOM`, then `DENY`, then `ALLOW`.
- A `CUSTOM` rejection or a `DENY` match ends the decision. Nothing after it is read.
- A workload with only `DENY` policies still allows everything they do not match. Only an `ALLOW` policy turns on default-deny.
- A `403` with the body `RBAC: access denied` comes from an `AuthorizationPolicy`. The receiving pod's access log names it in `rbac_access_denied_matched_policy[...]`.

**From [An ALLOW Cannot Override A DENY](./course-02-a-guest-list-cannot-overrule-the-ban.md):**

- A `DENY` match beats every `ALLOW`, however specific. There is no "most specific wins" for `AuthorizationPolicy`.
- You cannot cut an exception out of a `DENY` with an `ALLOW`. Write the exception into the `DENY`.
- A `DENY` hit and an `ALLOW` miss give the caller the same `403`. The receiving pod's access log tells them apart: a policy name, or `matched_policy[none]`.

**From [Deny All Traffic With One Empty Rule](./course-03-lock-everything-with-one-empty-rule.md):**

- `spec: {}` allows nothing. `rules: [{}]` allows everything. `action: DENY` with `rules: [{}]` denies everything, even with an open `ALLOW` policy in place.
- No rules fit nothing; one empty rule fits everything.
- A policy without a `selector` covers every pod in its namespace; in `istio-system`, every pod in the mesh.

**From [Deny A Path With Prefix Matching](./course-04-close-the-whole-path.md):**

- `paths` takes an exact path, a prefix (`/admin*`), a suffix (`*/admin`) or `*`.
- An exact path in a `DENY` leaves everything beneath it open. Use a prefix to close the whole area.
- Under `DENY`, a part you leave out covers every caller or every path.
- Test the path you did not write.

**From [Negative Fields In A DENY Policy](./course-05-say-it-out-loud-negative-fields.md):**

- `notMethods`, `notPaths`, `notPrincipals` and the other `not` fields mean "everything except".
- Read a policy as a sentence that starts with the action. `DENY` + `notMethods: ["GET"]` refuses every method except `GET`.
- `DENY` + `notPrincipals: ["*"]` refuses every request without a verified identity.

**From [AUDIT, And Choosing ALLOW Or DENY](./course-06-audit-and-choosing-allow-or-deny.md):**

- `AUDIT` records a match and never changes the response. It needs an audit provider to record anywhere.
- Write a new `DENY` as `AUDIT`, check it, then patch the action to `DENY`.
- Use `ALLOW` policies for the workload's normal traffic and a small `DENY` policy as the backstop.

## Your labs

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Close A Path With DENY](./labs/lab-01/README.md) | Deny A Path With Prefix Matching | ban a path and everything beneath it, and keep a careless `ALLOW` from reopening it |
| [Make The Probe Read-Only](./labs/lab-02/README.md) | Negative Fields In A DENY Policy | ban every method except `GET` with one negative field, while an open `ALLOW` policy stays in place |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. An <code>ALLOW</code> policy and a <code>DENY</code> policy both fit the same request. What happens?</summary>

The request is refused with `403`. The sidecar proxy checks the `DENY` policies before the `ALLOW` policies, and a `DENY` match ends the decision.
</details>

<details>
<summary>2. A workload has one <code>DENY</code> policy for <code>/status/*</code> and no other policy. What happens to <code>GET /get</code>?</summary>

It is allowed. A `DENY` does not turn on default-deny. With no `ALLOW` policy selecting the workload, everything the `DENY` does not match gets through.
</details>

<details>
<summary>3. Two callers both get <code>403 RBAC: access denied</code>. How do you find out whether a <code>DENY</code> fired or an <code>ALLOW</code> was missing?</summary>

Read the receiving pod's `istio-proxy` log. A `DENY` hit names the policy, for example `rbac_access_denied_matched_policy[ns[starfleet]-policy[probe-deny-status]-rule[0]]`. An `ALLOW` miss shows `matched_policy[none]`.
</details>

<details>
<summary>4. What is the difference between <code>spec: {}</code> and <code>rules: [{}]</code>?</summary>

`spec: {}` is an `ALLOW` with no rules: it turns on default-deny and fits nothing, so it allows nothing. `rules: [{}]` is one empty rule: it fits every request, so as an `ALLOW` it allows everything.
</details>

<details>
<summary>5. Your <code>DENY</code> uses <code>paths: ["/admin"]</code>. <code>/admin</code> returns 403. Are you done?</summary>

No. An exact path leaves `/admin/users` and everything else beneath it open. Use `paths: ["/admin*"]`, then test a deeper path.
</details>

<details>
<summary>6. Read this out loud: <code>action: DENY</code> with <code>notPaths: ["/health"]</code>. What does it do?</summary>

It refuses every path except `/health`. It is not a rule that protects `/health`.
</details>

<details>
<summary>7. You need <code>/admin/health</code> reachable while the rest of <code>/admin*</code> is denied. You add an <code>ALLOW</code> for <code>/admin/health</code>. Does it work?</summary>

No. The `DENY` is checked first and ends the decision. Put the exception into the `DENY` rule instead, for example `notPaths: ["/admin/health"]` next to `paths: ["/admin*"]`.
</details>

<details>
<summary>8. You change a <code>DENY</code> to <code>AUDIT</code>. What happens to the requests it matched?</summary>

They are no longer refused by it. `AUDIT` records the match and the sidecar proxy carries on, so the `ALLOW` policies (or their absence) decide the answer.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-020-02
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-020-02-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *The sidecar proxy checks `DENY` first. Deny narrowly and with prefixes, read every negative field as a sentence, and prove each rule with one request that passes and one that is refused.*
