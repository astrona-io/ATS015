# Turn An Identity Into An AuthorizationPolicy Principal

A workload's identity is a SPIFFE name in its certificate, such as `spiffe://cluster.local/ns/starfleet/sa/shuttle`. On its own, that name protects nothing. It only matters when a security rule on the receiving side checks it.

This chapter connects the two. You write one `AuthorizationPolicy` for the `probe` workload, see the right caller get through and the wrong ones get denied, and then break the policy on purpose with the most common mistake in this whole topic.
## The receiving proxy sees the caller's identity

A rule can only check an identity that the receiving workload knows. When two pods with sidecar proxies talk, Istio uses mutual TLS (mTLS) between them on its own, even before you write any rule. In mTLS, both sides present a certificate, so the connection is encrypted and both identities are verified. This is called **auto mTLS**, and it means the receiving workload's proxy already knows the caller's identity.

<!-- astrona:playground:renew -->

The `probe` workload echoes back the headers it received, and its sidecar proxy adds one header that shows the caller's identity:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A2 Client-Cert
```

```text
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=dc4c6e849118d690bc108450d6e35e656cbc177c01a26ee0d3690ece460a1f82;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
    ],
```

`By=` is the `probe` workload's own identity. `URI=` is the identity the `shuttle` proxy presented during the TLS handshake. The `probe` sidecar proxy read it from the certificate and passed it on to the application.

## Allow one caller with an AuthorizationPolicy

Now that the `probe` proxy knows who is calling, a rule can act on it. An `AuthorizationPolicy` allows or denies requests to a workload, by source, operation and conditions. Its field `principals` lists the caller identities a rule matches.

Before you write one, set up a quick test. Paste this helper. It sends one request to the `probe` Service from three clients: `shuttle` (`sa/shuttle`), `fortio` (`sa/default`) and `drifter` (no certificate at all):

```sh
check_callers() {
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" http://probe:8000/get
  kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 http://probe:8000/get 2>&1 | grep -o 'Code [0-9]*' | sed 's/Code /fortio:  /'
  kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" http://probe.starfleet:8000/get
}
check_callers
```

```text
shuttle: 200
fortio:  200
drifter: 200
```

With no policy, every request is allowed. Even the `drifter` request is allowed, because the `probe` proxy still accepts plain text by default.

The goal is to allow only `shuttle`. The `shuttle` certificate says `spiffe://cluster.local/ns/starfleet/sa/shuttle`. In `principals` you write the same name **without** `spiffe://`.

Save this as `authorizationpolicy-probe.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/shuttle
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe.yaml
```

Then check the result:

```sh
check_callers
```

```text
shuttle: 200
fortio:  403
drifter: 403
```

The `selector` picked which workloads the policy protects: the `probe` pods. The `probe` sidecar proxy did the check. `fortio` presented a real certificate with the wrong identity, so it got `403`. `drifter` presented no certificate at all, so there was no identity to match, and it got `403` too. The body of that response is `RBAC: access denied`: the `probe` proxy rejected the request before it reached the application.

One line was enough to deny every other caller because of how `ALLOW` works. Once an `ALLOW` policy exists for a workload, any request that matches no rule is denied.

> [!TIP]
> After you change a policy, give it up to a minute before you trust a test. In this playground, requests on connections that were already open sometimes kept the old rule for that long. Run your test twice; if the answers disagree, wait and run it again.

## The `spiffe://` trap

The certificate says `spiffe://...`, while `principals` must not. This one difference causes more silent failures than anything else in this topic, so it is worth seeing once on purpose.

Save this as `authorizationpolicy-probe-spiffe.yaml`. It is the same policy with `spiffe://` in front of the name:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - spiffe://cluster.local/ns/starfleet/sa/shuttle
```

Apply it, test, and ask `istioctl analyze` for help:

```sh
kubectl apply -f authorizationpolicy-probe-spiffe.yaml
check_callers
istioctl analyze -n starfleet
```

```text
authorizationpolicy.security.istio.io/probe configured
shuttle: 403
fortio:  403
drifter: 403

✔ No validation issues found when analyzing namespace: starfleet.
```

Now every request is denied, even the one from `shuttle`. Kubernetes accepted the object, and `istioctl analyze` sees nothing wrong. The rule simply never matches.

To find out why, ask the `probe` sidecar proxy what it really compares against. A listener is the part of Envoy that accepts connections on one port, and the inbound listener on port `15006` holds the policy rules:

```sh
istioctl proxy-config listener deploy/probe-v1 -n starfleet --port 15006 -o json \
  | grep -o '"exact": "[^"]*sa/shuttle"' | sort -u
```

```text
"exact": "spiffe://spiffe://cluster.local/ns/starfleet/sa/shuttle"
```

Istio adds `spiffe://` in front of every principal for you. Write it yourself, and the proxy looks for `spiffe://spiffe://...`, an identity no workload can ever have. To repair it, apply the correct policy again and check:

```sh
kubectl apply -f authorizationpolicy-probe.yaml
check_callers
```

```text
authorizationpolicy.security.istio.io/probe configured
shuttle: 200
fortio:  403
drifter: 403
```

Run the `proxy-config listener` command again and it shows `"exact": "spiffe://cluster.local/ns/starfleet/sa/shuttle"`: one `spiffe://`, added by Istio.

The general rule follows from this. `principals` takes `<trust-domain>/ns/<namespace>/sa/<service-account>`. Two wildcard forms are also allowed: `cluster.local/ns/starfleet/sa/*` matches every service account in the namespace, and `*` matches any caller that presented a certificate. The field `namespaces` takes plain namespace names, such as `starfleet`.

## Settling a denial in one pass

When a policy denies a request you expected to be allowed, the mistake sits in one of two places: the identity the caller really presents, or the name you wrote in the policy. Check both, in this order:

1. Read the caller's certificate with `istioctl proxy-config secret` and `openssl`.
2. Remove `spiffe://` from the name.
3. Compare it letter by letter with the `principals` entry.

A typo in the namespace name, a service account you guessed instead of read, and a stray `spiffe://` explain most cases.

The method also works the other way. A `principals` value tells you exactly which namespace and which service account a rule was written for. There is only one way to build that name, so you do not need to find the Deployment first.

## Changing the trust domain

Every `principals` value starts with the trust domain, `cluster.local` in your playground. The trust domain is the first part of every identity, set at install time in `meshConfig.trustDomain`. Teams often change it to their own name, so that identities from two meshes never collide. This is a topic to understand, not to run in the playground: changing it means installing Istio again and waiting for every workload to get a new certificate.

Suppose you change the trust domain to `acme.internal`. Istiod then issues every *new* certificate with the new trust domain. A policy that says `cluster.local/ns/starfleet/sa/shuttle` no longer matches a `shuttle` pod whose certificate says `acme.internal/ns/starfleet/sa/shuttle`. Nothing warns you, because both strings are valid.

It also does not happen all at once. Workloads get new certificates as they rotate, so for up to a day the mesh has a mix of old and new trust domains. The setting that makes this safe is `meshConfig.trustDomainAliases`, which lists extra trust domains the mesh treats as its own. With the old domain listed as an alias, policies that name `cluster.local/...` keep matching workloads that already have `acme.internal/...` certificates. That gives you time to update every policy before you remove the alias.

You now have the full path from certificate to rule. The receiving proxy reads the caller's identity, and an `AuthorizationPolicy` matches it in `principals`, written without `spiffe://`. When a request is denied, you read the caller's certificate, drop `spiffe://`, and compare: that one comparison settles every identity denial. What this policy does not do yet is force callers to use mTLS. The `drifter` was denied only because it had no identity to match, not because plain text was refused.

## Common pitfalls

> [!WARNING]
> - **Writing `spiffe://` in `principals`.** The object is accepted, `istioctl analyze` is clean, and the rule never matches. Leave the scheme out.
> - **Guessing the service account.** Read it from the certificate or from the pod. A Deployment without `serviceAccountName` runs as `default`.
> - **Expecting a selector to name the caller.** `selector` picks the workloads the policy protects. `principals` names the callers a rule matches.
> - **Forgetting plain-text callers.** A pod without a sidecar presents no certificate, so it never matches `principals` and gets `403`.
> - **Hard-coding `cluster.local` after a trust domain change.** Every `principals` entry stops matching, and at first only for some workloads.

## Your mission: Prove A Workload Identity And Authorize On It

You can now read a workload's identity from its live certificate and write an `AuthorizationPolicy` that allows exactly that identity. The graded lab asks you to prove it: in the namespace `identity-demo`, read the identity of `booking-service`, require STRICT mTLS for the whole namespace, and allow only `booking-service` to call `notification-service`. This lab runs its own small app (`booking-service`, `notification-service` and a `tester` client), not the Starfleet.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-010-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-010-01
astrona start ats-015-playground-010-01
```
