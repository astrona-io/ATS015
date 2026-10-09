# Match The Caller By Identity

A policy that lets in "any workload in the namespace" is better than no policy, but not by much. This part narrows an `ALLOW` rule to the exact identity in a workload's certificate. It shows why that identity only exists when mTLS works, and what happens when more than one `ALLOW` policy selects the same workload.

The commands below need `allow-nothing` and `probe-allow-shuttle-get` (only the `shuttle` may `GET` the `probe`) applied in your playground, and the three helpers from the module's landing page.

## The identity in the certificate

A `principals` rule names one caller by its workload identity. That identity is the SPIFFE ID in the workload's certificate. `istiod` builds it from the pod's namespace and its Kubernetes service account.

### The format

```text
cluster.local/ns/starfleet/sa/shuttle
└──────────┘    └───────┘    └─────┘
trust domain    namespace    service account
```

The certificate itself carries `spiffe://cluster.local/ns/starfleet/sa/shuttle`. In a `principals` rule you leave out the `spiffe://` part. A rule that keeps it matches nothing, and nothing warns you.

### Find each workload's service account

<!-- astrona:playground:renew -->

You never guess a principal. You read the service account off the pods. First, remove the `probe-allow-headers` policy if your namespace still has it. It lets any caller read `/headers`, which would hide the effect of the steps below:

```sh
kubectl delete authorizationpolicy probe-allow-headers -n starfleet --ignore-not-found
```

Then list every pod with its service account:

```sh
kubectl get pods -n starfleet -o custom-columns=POD:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
```

```text
POD                          SERVICEACCOUNT
bridge-v1-bc4dc4fcc-b6r5k    starfleet-bridge
cargo-v1-6f787f8bd5-5ll2s    starfleet-cargo
fortio-5b7645966b-6v6p7      default
navcom-v1-7467bbc689-tt9mz   starfleet-navcom
probe-v1-7888d6c6d5-gtn9x    probe
probe-v2-58767cc46-gkbn7     probe
scout-v1-85bf65868-cnm7p     starfleet-scout
scout-v2-866c98b568-srjwq    starfleet-scout
scout-v3-668c6dfc68-6d5gm    starfleet-scout
shuttle-7b5db664c-bn84s      shuttle
```

The output shows two things worth remembering. `fortio` has no service account of its own, so it runs as `default`. And all three `scout` versions share `starfleet-scout`, so a `principals` rule cannot tell them apart.

A `principals` rule is about the service account, not the pod. Give another pod the same service account, and it gets the same identity and the same access.

## Why the identity needs mTLS

A `principals` rule compares an identity that mTLS verified. If there is no mTLS, there is no certificate, and the rule has nothing to compare.

### No certificate, no match

Take a pod with no sidecar, like the `drifter`. It sends plain text, so it never presents a certificate. In a namespace in `PERMISSIVE` mode, its request passes the mTLS check and reaches the authorization check with no identity at all. The RBAC filter compares an empty identity against the rules, finds no match, and answers `403`. The denial has nothing to do with who the caller is.

In your namespace `PeerAuthentication` is `STRICT`, so the `drifter` is cut off one stage earlier with a reset connection. It never reaches the authorization check at all. That is why this playground switches on `STRICT` before anything else.

So when "my `principals` rule denies everyone", check `PeerAuthentication` first, not the rule.

## A whole namespace at once

Sometimes the right caller is "every workload in this namespace", whatever its service account. The `namespaces` field does that. It reads the namespace from the same certificate, so it also needs mTLS.

### Allow every workload in starfleet

Save this as `authorizationpolicy-probe-allow-starfleet-ns.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-starfleet-ns
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["starfleet"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-allow-starfleet-ns.yaml
```

Then check the result from all three callers:

```sh
from_fortio http://probe:8000/get
from_shuttle -X POST http://probe:8000/post
from_drifter http://probe.starfleet:8000/get
```

```text
Code 200
200 200 200 <- -X POST http://probe:8000/post
drifter: 000
command terminated with exit code 56
```

`fortio` now gets in: its certificate says namespace `starfleet`, and the service account no longer matters. The `shuttle`'s `POST` gets in too, because this new rule has no `to` part. The `drifter` is still cut off by mTLS.

## Two policies on one workload

The `probe` is now selected by three `ALLOW` policies: `allow-nothing`, `probe-allow-shuttle-get` and `probe-allow-starfleet-ns`. The `shuttle`'s `POST` was denied a moment ago, and now it gets in. Adding a policy let **more** requests in.

### The union rule

The proxy combines every `ALLOW` policy that selects a workload. A request gets in if it matches a rule in **any** of them:

```text
   allow-nothing              rules: []                      --+
   probe-allow-shuttle-get    rules: [shuttle, GET]            +-->  OR  -->  allowed if any fits
   probe-allow-starfleet-ns   rules: [namespace starfleet]   --+
```

This is the opposite of most people's first guess. **Adding `ALLOW` policies can only ever let more in.** The narrowing happened once, when the first `ALLOW` policy selected the workload. To take something away, you need a `DENY` policy, which the proxy checks before any `ALLOW` policy.

Compare that with `PeerAuthentication`, where only one policy applies to a workload:

| Object | Several policies on one workload |
| --- | --- |
| `PeerAuthentication` | the most specific scope wins; the others are ignored |
| `AuthorizationPolicy` (`ALLOW`) | all of them count; their rules add up (a union) |

Remove the namespace-wide policy before you go on, so the `probe` is back to "only the `shuttle` may `GET`":

```sh
kubectl delete -f authorizationpolicy-probe-allow-starfleet-ns.yaml
```

## Common pitfalls

> [!WARNING]
> - **Using `principals` or `namespaces` without mTLS.** No verified certificate means no identity, so the rule never matches. Check `PeerAuthentication` first.
> - **Writing `spiffe://` in `principals`.** The field takes the name without the scheme. The wrong form is accepted and matches nothing.
> - **Guessing the service account.** Read it from the pod. `fortio` runs as `default`, and the `scout` pods share one account.
> - **Expecting another `ALLOW` policy to restrict.** `ALLOW` policies add up. To take something away, you need `DENY`.
> - **Using `namespaces` where one caller was meant.** Every workload in the namespace gets in, including ones deployed later.

> *`principals` matches the identity that mTLS verified, so it needs mTLS. Every `ALLOW` policy on a workload adds to a union that can only let more in.*

## Your mission: Lock A Namespace Down With ALLOW Policies

You can now close a namespace, allow one call by namespace and another by exact identity, and limit each call to one method and path. The graded lab asks you to lock down a small booking app and reopen exactly the two calls its design needs.

This lab runs on a small app of its own, not the Starfleet: `booking-service` (service account `booking-sa`), `notification-service` and a `tester` client, in the namespace `authz-demo` with `STRICT` mTLS already on. The task in `question.md` describes it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-020-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-020-01
astrona start ats-015-playground-020-01
```
