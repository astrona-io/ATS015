# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about the ID badge every ship carries: where it comes from, how to read it, and how a security rule matches on it.

**From [How A Ship Gets Its Badge](./course-01-how-a-ship-gets-its-badge.md):**

- A ship's identity comes from its **service account**, not from its pod name or labels. The shape is `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`.
- Ships that share a service account share one identity. `scout` v1, v2 and v3 all carry `.../sa/starfleet-scout`, and no rule can tell them apart.
- The service account token is the proof. Its `audience` is `istio-ca`, and istiod checks it with the Kubernetes API before it signs.
- The istio-agent makes the private key in memory and hands the certificate to Envoy over SDS. No Kubernetes Secret holds workload keys.
- The trust domain, `cluster.local` by default, is one setting for the whole mesh, in `meshConfig.trustDomain`.

**From [Read The Badge A Ship Carries](./course-02-read-the-badge-a-ship-carries.md):**

- `istioctl proxy-config secret` shows what a running proxy holds: `default` (the ship's own badge) and `ROOTCA` (the seal it checks others against).
- The name sits in the certificate's SAN, as a URI. The subject is empty.
- `-o json`, `jq`, `base64 --decode` and `openssl x509 -ext subjectAltName` read it.
- A ship without a sidecar, like the drifter, has no badge.
- Badges live 24 hours and are renewed after about half that time, with no restart. A stale badge means the proxy lost istiod.

**From [From Badge To Guest List](./course-03-from-badge-to-guest-list.md):**

- Between two ships with sidecars, auto mTLS does the handshake, so the receiver knows the caller's name.
- `principals` takes the name **without** `spiffe://`. With it, the object is accepted, `istioctl analyze` is clean, and the proxy looks for `spiffe://spiffe://...`, which never matches.
- An `ALLOW` list shuts out everyone not on it, including plain-text callers that show no badge.
- To settle a denial: read the caller's badge, drop `spiffe://`, compare letter by letter.
- Changing the trust domain breaks every `principals` value that names the old one. `meshConfig.trustDomainAliases` keeps both working during the move.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Prove A Workload Identity And Authorize On It](./labs/lab-01/README.md) | From Badge To Guest List | read a badge from a live certificate and let in only that badge |

If you skipped it, go back to it now. It is short, and the exam asks for exactly this skill.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Two Deployments both run without a <code>serviceAccountName</code>. Can an <code>AuthorizationPolicy</code> allow one and deny the other by identity?</summary>

No. Both run as `default`, so both carry the same badge, `.../sa/default`. Give each Deployment its own service account if a rule must tell them apart.
</details>

<details>
<summary>2. <code>istioctl proxy-config secret</code> shows two rows. Which one holds the ship's identity?</summary>

`default`. It is the ship's own certificate, with the SPIFFE name in its SAN. `ROOTCA` is the root certificate the ship uses to check other ships' badges.
</details>

<details>
<summary>3. You decode a mesh certificate and the <code>subject</code> line is empty. Is something broken?</summary>

No. Mesh certificates leave the subject empty and carry the identity only in the SAN, as a `spiffe://` URI.
</details>

<details>
<summary>4. Your rule lists <code>spiffe://cluster.local/ns/starfleet/sa/shuttle</code>. What happens to the shuttle's signals?</summary>

They get `403`. Istio adds `spiffe://` itself, so the proxy looks for `spiffe://spiffe://...`. The object is accepted and `istioctl analyze` stays quiet. Write `cluster.local/ns/starfleet/sa/shuttle`.
</details>

<details>
<summary>5. istiod goes down. When do the ships start failing?</summary>

Not right away. Ships keep working on their current badges. They fail only when those badges expire, at most 24 hours later, if istiod is still down.
</details>

<details>
<summary>6. A team changes <code>meshConfig.trustDomain</code> to <code>acme.internal</code>. What happens to a rule that lists <code>cluster.local/ns/starfleet/sa/shuttle</code>?</summary>

It stops matching ships that carry new badges, and at first only some ships have them. List `cluster.local` in `meshConfig.trustDomainAliases` while you update the rules.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-010-01
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-015-lab-010-01
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *Every security rule in the mesh matches on a badge that istiod printed from a service account. Read the badge, and you know what the rule must say.*
