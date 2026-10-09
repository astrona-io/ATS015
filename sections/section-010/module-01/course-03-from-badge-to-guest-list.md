# From Badge To Guest List

Astronaut, you can now read the name on any ship's badge. This part turns that name into the string a security rule matches on. You will write one guest list for the `probe`, watch the right ship get through and the wrong ones stay outside, and then break the list on purpose with the most common mistake in this whole topic.

## The receiving ship sees the caller's badge

A badge only matters if the ship on the other end reads it. When two ships with communications officers talk, Istio does the secret handshake (mTLS) for them on its own, even before you write any rule. This is called **auto mTLS**. So the receiving ship's proxy knows the caller's name.

### See it in your playground

<!-- astrona:playground:renew -->

The probe echoes back the headers it received. Its proxy adds one header that shows the caller's badge:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A2 Client-Cert
```

```text
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=dc4c6e849118d690bc108450d6e35e656cbc177c01a26ee0d3690ece460a1f82;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
    ],
```

`By=` is the probe's own badge. `URI=` is the badge the shuttle showed during the handshake. The probe's communications officer read it and passed it on to the crew.

## The guest list matches the badge

An `AuthorizationPolicy` is the guard's list at the airlock: who may come aboard and what they may do. Its field `principals` lists the badge names that may come in. Before you write one, set up a quick test.

### A helper to test three callers

Paste this helper. It sends one signal to the probe from three ships: the shuttle (`sa/shuttle`), fortio (`sa/default`) and the drifter (no badge at all):

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

With no rule, every ship gets in. Even the drifter gets in, because the probe still accepts plain text by default.

### Write the guest list

The shuttle's badge says `spiffe://cluster.local/ns/starfleet/sa/shuttle`. In `principals` you write the same name **without** `spiffe://`.

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

The `selector` picked which ships the guard protects: the probes. The probe's own communications officer did the check. Fortio showed a real badge with the wrong name, so it got `403`. The drifter showed no badge at all, so there was no name to match, and it got `403` too. The body of that answer is `RBAC: access denied`: the guard turned the signal away at the airlock.

Once an `ALLOW` list exists for a ship, anyone not on it stays outside. That is why one line is enough to shut out every other caller.

> [!TIP]
> After you change a policy, give it up to a minute before you trust a test. In this playground, signals on connections that were already open sometimes kept the old rule for that long. Run your test twice; if the answers disagree, wait and run it again.

## The `spiffe://` trap

The badge says `spiffe://...`, but `principals` must not. This one difference causes more silent failures than anything else in this topic, so see it once on purpose.

### Break the list

Save this as `authorizationpolicy-probe-spiffe.yaml`. It is the same list with `spiffe://` in front of the name:

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

Now nobody gets in, not even the shuttle. Kubernetes accepted the object, and `istioctl analyze` sees nothing wrong. The rule simply never matches.

### Why it never matches

Ask the probe's communications officer what it really compares against. The inbound listener on channel `15006` holds the guard's list:

```sh
istioctl proxy-config listener deploy/probe-v1 -n starfleet --port 15006 -o json \
  | grep -o '"exact": "[^"]*sa/shuttle"' | sort -u
```

```text
"exact": "spiffe://spiffe://cluster.local/ns/starfleet/sa/shuttle"
```

Istio adds `spiffe://` in front of every principal for you. Write it yourself, and the proxy looks for `spiffe://spiffe://...`, a badge no ship can ever carry.

### Put it back

Apply the correct list again and check:

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

### The rule

`principals` takes `<trust-domain>/ns/<namespace>/sa/<service-account>`. Two wildcard forms are also allowed: `cluster.local/ns/starfleet/sa/*` matches every service account on the planet, and `*` matches any ship that showed a badge. The field `namespaces` takes plain namespace names, such as `starfleet`.

## Settling a denial in one pass

When a guest list turns away a signal you expected to get through, the mistake sits in one of two places: the badge the caller really shows, or the name you wrote in the list. Check both, in this order:

1. Read the caller's badge with `istioctl proxy-config secret` and `openssl`.
2. Remove `spiffe://` from the name.
3. Compare it letter by letter with the `principals` entry.

A typo in the planet name, a service account you guessed instead of read, and a stray `spiffe://` explain most cases.

The method also works the other way. A `principals` value tells you exactly which planet and which service account a rule was written for. There is only one way to build that name, so you do not need to find the Deployment first.

## Changing the trust domain

The trust domain is the first part of every badge name, `cluster.local` in your playground. It is the fleet's official seal, set at install time in `meshConfig.trustDomain`, and teams often change it to their own name, so that badges from two meshes never collide. This is a topic to understand, not to run in the playground: changing it means installing Istio again and waiting for every ship to get a new badge.

### What breaks

Change the trust domain to, for example, `acme.internal`, and istiod prints every *new* badge with the new seal. A guest list that says `cluster.local/ns/starfleet/sa/shuttle` no longer matches a shuttle whose badge says `acme.internal/ns/starfleet/sa/shuttle`. Nothing warns you, because both strings are valid.

It also does not happen all at once. Ships get new badges as they rotate, so for up to a day the fleet carries a mix of old and new seals.

### What helps

`meshConfig.trustDomainAliases` lists extra trust domains the mesh treats as its own. With the old domain listed as an alias, guest lists that name `cluster.local/...` keep matching ships that already carry `acme.internal/...` badges. That gives you time to update every list before you remove the alias.

## Common pitfalls

> [!WARNING]
> - **Writing `spiffe://` in `principals`.** The object is accepted, `istioctl analyze` is clean, and the rule never matches. Leave the scheme out.
> - **Guessing the service account.** Read it from the badge or from the pod. A Deployment without `serviceAccountName` runs as `default`.
> - **Expecting a selector to name the caller.** `selector` picks the ships the guard protects. `principals` names who may come in.
> - **Forgetting plain-text callers.** A ship without a sidecar shows no badge, so it never matches `principals` and gets `403`.
> - **Hard-coding `cluster.local` after a trust domain change.** Every `principals` entry stops matching, and at first only for some ships.

> *Read the badge off the caller, drop `spiffe://`, and compare it with the guest list: that one comparison settles every identity denial.*

## Your mission: Prove A Workload Identity And Authorize On It

You can now read a ship's badge from its live certificate and write a guest list that lets in exactly that badge. Now prove it in a graded mission: on a planet called `identity-demo`, read the badge of `booking-service`, require the secret handshake for the whole planet, and let only `booking-service` call `notification-service`. This mission runs its own small app (`booking-service`, `notification-service` and a `tester` client), not the Starfleet.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-010-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-010-01
astrona start ats-015-playground-010-01
```
