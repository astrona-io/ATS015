# Wrap-Up: Workload Identity And Certificates

Every security rule in the mesh matches on one thing: the identity of the workload that sends the request. This module followed that identity from where it comes from, to where it lives, to how a rule checks it.

## What you learned

A workload's identity comes from its **service account**, not from its pod name or its labels. Istio uses the service account because its token is the only proof about a pod that someone else can check. Istiod checks that token with the Kubernetes API, then signs a certificate with a name in a fixed shape: `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`. So workloads that share a service account share one identity, and no rule can tell them apart.

The certificate lives only in the sidecar proxy. The istio-agent makes the private key in memory and hands the certificate to Envoy over SDS (Secret Discovery Service), so no Kubernetes Secret holds workload keys. `istioctl proxy-config secret` shows what a proxy holds: `default`, the workload's own certificate, and `ROOTCA`, the root certificate it checks other workloads against. The name sits in the certificate's SAN (Subject Alternative Name) as a URI, and the subject is empty. A pod without a sidecar has no certificate and no identity.

Certificates are short-lived, but the name stays fixed. A workload certificate lives 24 hours, and the istio-agent renews it after about half that time, with no restart. If istiod is down, proxies keep working until their certificates expire. So a stale certificate points to a lost connection to istiod, not to a broken certificate.

An `AuthorizationPolicy` uses the identity in its `principals` field. Between two pods with sidecars, auto mTLS lets the receiving proxy read the caller's identity, and an `ALLOW` policy denies every request that matches no rule. The key facts to remember are these:

- `principals` takes the name **without** `spiffe://`, for example `cluster.local/ns/starfleet/sa/shuttle`. With `spiffe://`, the object is accepted, `istioctl analyze` is clean, and the rule never matches.
- To settle a denial, read the caller's certificate, drop `spiffe://`, and compare it letter by letter with the policy.
- The trust domain, `cluster.local` by default, is set in `meshConfig.trustDomain`. Changing it breaks every `principals` value that names the old one, and `meshConfig.trustDomainAliases` keeps both working during the move.

In short: read the identity in the certificate, and you know what the rule must say.

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

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running. First, see what is still running:

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
