# Summary

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

When you are done, remove the playground with `astrona destroy ats-015-playground-010-01`.
