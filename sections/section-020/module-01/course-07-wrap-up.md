# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and every mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about one object, the `AuthorizationPolicy`: the guard's list at the airlock that decides who may come aboard and what they may do.

**From [The Guard At The Airlock](./course-01-the-guard-at-the-airlock.md):**

- The guard runs in the proxy of the ship that **receives** the signal, as Envoy's RBAC filter. `istiod` compiles each policy into that filter for the pods its `selector` matches.
- The checks run in a fixed order: the handshake (`PeerAuthentication`), then HTTP is read, then the token check (`RequestAuthentication`), then the guard (`AuthorizationPolicy`).
- With no policy selecting a ship, every signal that passes the handshake gets in.
- A cut connection (`000`, curl exit code `56`) is the handshake, not the guard. The guard answers `403` with the body `RBAC: access denied`.
- The caller learns almost nothing. The reason is in the receiving ship's flight log.

**From [Close The Airlock](./course-02-close-the-airlock.md):**

- `spec: {}` means action `ALLOW`, every workload in the namespace, and no rules. It allows nothing.
- Default-deny is created by the first `ALLOW` policy that selects a workload.
- The guard checks `CUSTOM`, then `DENY`, then `ALLOW`. No `ALLOW` on a ship means allowed; otherwise a signal needs a matching `ALLOW` rule.
- `rules: [{}]` is one empty rule, and it matches every signal. It is the opposite of `spec: {}`.
- A policy with no selector covers its own namespace, or the whole mesh when it lives in the root namespace `istio-system`.
- The flight log shows `rbac_access_denied_matched_policy[none]` when no `ALLOW` rule matched.

**From [Write A Guest List Entry](./course-03-write-a-guest-list-entry.md):**

- A rule has up to three parts: `from` (who), `to` (which operation) and `when` (extra conditions).
- Values in one field are combined with OR; fields and parts with AND; rules and policies with OR.
- A part you leave out is a wildcard, not a limit.
- Paths match exactly, by prefix (`/status/*`) or by suffix (`*/status`). There is no regular expression, and the query string is ignored.

**From [Name The Caller](./course-04-name-the-caller.md):**

- A principal is `<trust domain>/ns/<namespace>/sa/<service account>`, without `spiffe://`.
- Read service accounts from the pods: fortio runs as `default`, and all scouts share `starfleet-scout`.
- `principals` and `namespaces` both come from the mTLS badge, so they need mTLS to match.
- All `ALLOW` policies on a ship add up. Another `ALLOW` policy can only let more in; to take something away you need `DENY`.

**From [Least Privilege For The Whole Fleet](./course-05-least-privilege-for-the-fleet.md):**

- Map who calls whom first; each arrow becomes one rule on the receiving ship's list.
- The bridge accepts `GET` from anyone with a badge; `cargo` and `scout` only from `starfleet-bridge`; `navcom` only from `starfleet-scout`.
- Prove it both ways: the page works, and the shortcuts from the shuttle get `403`.
- Apply the narrow lists first and the empty list last.

**From [Find Out Why The Guard Says No](./course-06-find-out-why-the-guard-says-no.md):**

- A policy that seems to do nothing either never reached the ship or arrived with a rule that does not fit.
- `istioctl proxy-config listener <pod> --port 15006 -o json` shows which policies the receiving proxy holds.
- `istioctl analyze` reports a policy whose selector matches no workload.
- The receiver's flight log shows which list decided.

## Your missions

You proved each skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Lock A Namespace Down With ALLOW Policies](./labs/lab-01/README.md) | Name The Caller | close a namespace and reopen two calls, one by namespace and one by exact identity |
| [Repair The Fleet's Guest Lists](./labs/lab-02/README.md) | Find Out Why The Guard Says No | find a list that never arrived and a rule that names the wrong caller, and fix both without opening shortcuts |

If you skipped one, go back to it now. Each mission is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. A namespace has no <code>AuthorizationPolicy</code>. mTLS is <code>STRICT</code>. May any meshed workload call any other?</summary>

Yes. `STRICT` only demands the handshake. With no policy selecting a workload, the guard has no list, and every signal that passes the handshake gets in.
</details>

<details>
<summary>2. What does <code>spec: {}</code> do, and what does <code>rules: [{}]</code> do?</summary>

`spec: {}` is an `ALLOW` policy for every workload in the namespace with no rules, so it allows nothing. `rules: [{}]` is one rule with no conditions, so it matches every signal and allows everything.
</details>

<details>
<summary>3. A rule has a <code>from</code> with one principal and no <code>to</code>. What may that caller do?</summary>

Anything. A part you leave out is a wildcard. To limit the caller to some methods or paths, add a `to` part to the **same** rule.
</details>

<details>
<summary>4. You add a second <code>ALLOW</code> policy that looks stricter than the first. Does the workload get stricter?</summary>

No. All `ALLOW` policies on a workload add up, so a second one can only let more signals in. To take something away, use a `DENY` policy.
</details>

<details>
<summary>5. Your <code>principals</code> rule refuses every caller, including the one it names. What do you check?</summary>

First the principal string: no `spiffe://`, the right namespace and the real service account read from the pod. Then mTLS: without the handshake there is no badge, and the rule cannot match.
</details>

<details>
<summary>6. A caller gets <code>000</code> and curl exit code <code>56</code>. Is that your <code>AuthorizationPolicy</code>?</summary>

No. That is a reset connection from the handshake check, usually `STRICT` mTLS meeting a caller with no sidecar. The guard answers with a full `403` and `RBAC: access denied`.
</details>

<details>
<summary>7. <code>kubectl get authorizationpolicy</code> lists your policy, but it changes nothing. What two causes are possible, and how do you tell them apart?</summary>

Either it never reached the workload (a `selector` that matches no pod, or the wrong namespace) or its rules do not fit. `istioctl proxy-config listener` on the receiver shows whether the policy arrived, and `istioctl analyze` flags a selector that matches nothing.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-020-01
```

If `astrona list` also showed a mission, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-020-01-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *With no list, the guard lets everyone in. The first `ALLOW` list closes the airlock, every list on a ship adds up, and each caller is named by the badge the handshake checked.*
