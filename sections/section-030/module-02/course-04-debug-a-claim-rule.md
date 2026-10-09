# Debug A Claim Rule

A claim rule that is wrong usually gives no error. Kubernetes accepts it, `istiod` (Istio's control plane) sends it to the proxies, and the proxy quietly refuses every request. On the exam, and in real work, you need a fast way to find out why.

In this chapter you break a rule on purpose, find the cause with two commands, and fix it. First, though, it helps to know what can go wrong, because three different faults look almost the same from the outside.

## Three causes, three fixes

When the right user gets `403` from a claim rule, one of three things is usually wrong. Each one has a different fix:

| What is wrong | What you see | Where to look |
| --- | --- | --- |
| The claim name or value is wrong | The rule reached the proxy, but no token fits it | decode the token, read the rule in the proxy |
| No `RequestAuthentication` selects the workload | No `request.auth` attributes at all, so every claim rule fails | `kubectl get requestauthentication -n <namespace>` and its `selector` |
| The policy's `selector` matches no pod | The policy does nothing at all, for anyone | the rule is missing from the proxy |

The first two both look like "the right user is refused". The third looks like "the policy changed nothing". Reading the proxy's configuration separates them, as the rest of this chapter shows.

## Break the claim name

The first cause is the most common one, so make it happen. The rule below asks for `request.auth.claims[group]`, but the real claim in the token is `groups`. Only one letter is missing.

<!-- astrona:playground:renew -->

If your terminal is new, paste the helpers first:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
GROUPS_TOKEN=$(curl -s $SAMPLES_URL/groups-scope.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

Save this as `authorizationpolicy-probe-require-jwt.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-require-jwt
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[group]
      values: ["group1"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Wait about a minute, then send requests with the groups token, which really is in `group1`:

```sh
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers
```

```text
403 403 403 
```

The right user is refused, and nothing told you why.

## Find the cause

Two checks settle it. First you ask Istio's own checker, then you read the rule the probe's sidecar proxy actually holds.

`istioctl analyze` runs Istio's checks over the objects in a namespace:

```sh
istioctl analyze -n starfleet
```

```text

✔ No validation issues found when analyzing namespace: starfleet.
```

It finds nothing. `analyze` cannot know which claims your issuer puts in its tokens, so a wrong claim name looks fine to it.

The proxy itself is the better witness. The authorization filter's rules live in the probe's inbound listener, the part of the proxy's configuration that handles requests coming in. It is a long JSON dump. Inside the proxy, a claim rule does not say `request.auth.claims` any more: it reads the token's `payload` that the JWT filter left behind, and then the claim name. This command picks out every claim name the proxy compares:

```sh
istioctl proxy-config listener deploy/probe-v1 -n starfleet -o json \
  | grep -A3 '"key": "payload"' | grep '"key"' | grep -v payload | tr -d ' ' | sort -u
```

```text
"key":"group"
"key":"iss"
"key":"sub"
```

`iss` and `sub` come from `requestPrincipals: ["*"]`: the proxy checks that the token has an issuer and a subject. `group` comes from the `when` block. So the rule reached the proxy, which means the `selector` is fine, and the claim it compares is `group`. Now compare that with the decoded token:

```sh
echo "$GROUPS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":3537391104,"groups":["group1","group2"],"iat":1537391104,"iss":"testing@secure.istio.io","scope":["scope1","scope2"],"sub":"testing@secure.istio.io"}
```

The token says `groups`, and the rule says `group`. That one letter is the whole fault. If the `proxy-config` command had printed nothing at all, the policy would never have reached this proxy, and you would check its `selector` against the pod labels instead.

> [!TIP]
> When a claim rule refuses the right user, put two things side by side: the claim names from `proxy-config` and the decoded token. Two things you can both see settle it in seconds, where guessing can take an hour.

## Fix it

Now that you know the cause, the fix is one word. In `authorizationpolicy-probe-require-jwt.yaml`, change the key to `request.auth.claims[groups]`, so the `when` block reads:

```yaml
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Wait about a minute, then check the result with both tokens:

```sh
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers
check_status -H "$AUTH $TOKEN" $PROBE/headers
```

```text
200 200 200 
403 403 403 
```

The groups token gets in, and the demo token, which has no `groups` claim, is still refused. If you run the `proxy-config` command again, it now prints `"key":"groups"`. Clean up with `kubectl delete authorizationpolicy probe-require-jwt -n starfleet` before you start the lab.

You now have a short routine for a claim rule that refuses everyone. A clean `istioctl analyze` proves little. The claim names in the proxy show whether the rule arrived and what it compares, and the decoded token shows what it should compare. If no claim names appear, the `selector` is the problem; if no `RequestAuthentication` selects the workload, no claim rule can ever fit.

## Common pitfalls

> [!WARNING]
> - **Trusting a clean `istioctl analyze`.** It does not know your issuer's claim names. A wrong claim name passes every check.
> - **Guessing instead of comparing.** Decode the refused token and put it next to the rule from `proxy-config`.
> - **Missing that the rule never arrived.** If `proxy-config` shows no claim name at all, the problem is the policy's `selector`, not the claim.
> - **Forgetting the `RequestAuthentication`.** Without one on the workload, no claims are published and every claim rule fails, even a correct one.

## Your mission: Fix The Claim Rule

You can now find a broken claim rule from the proxy's configuration and a decoded token. The graded lab gives you a policy on the probe that refuses the administrator group and blocks a path that should be public. You have to find and fix both faults.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-030-02
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-02/labs/lab-02
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-030-02-02
astrona start ats-015-playground-030-02
```
