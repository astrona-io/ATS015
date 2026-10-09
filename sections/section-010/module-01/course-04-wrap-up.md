# Wrap-Up: Workload Identity And Certificates

You have finished every part and the graded lab in this module. Before you move on, look back at what you learned, check yourself, and clean up the playground.

## What you learned

This module was about the identity in every workload's certificate: where it comes from, how to read it, and how a security rule matches on it.

**From [How A Workload Gets Its Certificate](./course-01-how-a-ship-gets-its-badge.md):**

- A workload's identity comes from its **service account**, not from its pod name or labels. The shape is `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`.
- Workloads that share a service account share one identity. `scout` v1, v2 and v3 all have `.../sa/starfleet-scout`, and no rule can tell them apart.
- The service account token is the proof. Its `audience` is `istio-ca`, and istiod checks it with the Kubernetes API before it signs.
- The istio-agent makes the private key in memory and hands the certificate to Envoy over SDS. No Kubernetes Secret holds workload keys.
- The trust domain, `cluster.local` by default, is one setting for the whole mesh, in `meshConfig.trustDomain`.

**From [Read A Workload's Certificate](./course-02-read-the-badge-a-ship-carries.md):**

- `istioctl proxy-config secret` shows what a running proxy holds: `default` (the workload's own certificate) and `ROOTCA` (the root certificate it checks others against).
- The name sits in the certificate's SAN, as a URI. The subject is empty.
- `-o json`, `jq`, `base64 --decode` and `openssl x509 -ext subjectAltName` read it.
- A pod without a sidecar, like `drifter`, has no certificate and no identity.
- Workload certificates live 24 hours and are renewed after about half that time, with no restart. A stale certificate means the proxy lost its connection to istiod.

**From [Turn An Identity Into An AuthorizationPolicy Principal](./course-03-from-badge-to-guest-list.md):**

- Between two pods with sidecars, auto mTLS sets up mutual TLS, so the receiving proxy knows the caller's identity.
- `principals` takes the name **without** `spiffe://`. With it, the object is accepted, `istioctl analyze` is clean, and the proxy looks for `spiffe://spiffe://...`, which never matches.
- An `ALLOW` policy denies every request that matches no rule, including plain-text callers that present no certificate.
- To settle a denial: read the caller's certificate, drop `spiffe://`, compare letter by letter.
- Changing the trust domain breaks every `principals` value that names the old one. `meshConfig.trustDomainAliases` keeps both working during the move.

## Your missions

You proved the skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Prove A Workload Identity And Authorize On It](./labs/lab-01/README.md) | Turn An Identity Into An AuthorizationPolicy Principal | read an identity from a live certificate and allow only that identity |

If you skipped it, go back to it now. It is short, and the exam asks for exactly this skill.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Two Deployments both run without a <code>serviceAccountName</code>. Can an <code>AuthorizationPolicy</code> allow one and deny the other by identity?</summary>

No. Both run as `default`, so both have the same identity, `.../sa/default`. Give each Deployment its own service account if a rule must tell them apart.
</details>

<details>
<summary>2. <code>istioctl proxy-config secret</code> shows two rows. Which one holds the workload's identity?</summary>

`default`. It is the workload's own certificate, with the SPIFFE name in its SAN. `ROOTCA` is the root certificate the proxy uses to check the certificates of other workloads.
</details>

<details>
<summary>3. You decode a mesh certificate and the <code>subject</code> line is empty. Is something broken?</summary>

No. Mesh certificates leave the subject empty and carry the identity only in the SAN, as a `spiffe://` URI.
</details>

<details>
<summary>4. Your rule lists <code>spiffe://cluster.local/ns/starfleet/sa/shuttle</code>. What happens to requests from <code>shuttle</code>?</summary>

They get `403`. Istio adds `spiffe://` itself, so the proxy looks for `spiffe://spiffe://...`. The object is accepted and `istioctl analyze` stays quiet. Write `cluster.local/ns/starfleet/sa/shuttle`.
</details>

<details>
<summary>5. istiod goes down. When do the workloads start failing?</summary>

Not right away. Proxies keep working with their current certificates. They fail only when those certificates expire, at most 24 hours later, if istiod is still down.
</details>

<details>
<summary>6. A team changes <code>meshConfig.trustDomain</code> to <code>acme.internal</code>. What happens to a rule that lists <code>cluster.local/ns/starfleet/sa/shuttle</code>?</summary>

It stops matching workloads that have new certificates, and at first only some workloads have them. List `cluster.local` in `meshConfig.trustDomainAliases` while you update the rules.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-010-01
```

If `astrona list` also showed the lab, remove it the same way:

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

> *Every security rule in the mesh matches on an identity that istiod built from a service account. Read the identity in the certificate, and you know what the rule must say.*
