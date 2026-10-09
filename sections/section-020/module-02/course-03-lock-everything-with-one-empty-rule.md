# Deny All Traffic With One Empty Rule

Three policies in authorization look almost the same on paper and do opposite things. One pair of curly braces in the wrong place turns "deny all requests" into "allow all requests", and `kubectl apply` accepts both without a word. Exam tasks love this, because a quick reader gets it wrong.

This chapter teaches you to read all three at a glance. Then you use the strongest one to deny all traffic in a namespace, even while a policy that allows everything is still in place.

## Three look-alike specs

The difference between the three is how many rules the policy has, and what is inside a rule. Learn this table by heart:

| Spec | What the sidecar proxy does |
| --- | --- |
| `spec: {}` | allow nothing (deny all) |
| `rules: [{}]` | allow everything |
| `action: DENY` + `rules: [{}]` | deny everything, even with `ALLOW` policies in place |

The first row, `spec: {}`, is an `ALLOW` policy (`ALLOW` is the default action) with **no rules**. It turns on default-deny for every pod it selects. Since it has no rules, no rule can fit, so nothing gets in.

The second row, `rules: [{}]`, is an `ALLOW` policy with **one empty rule**. An empty rule has no conditions, and a rule with no conditions fits every request. So everything gets in.

The third row puts that same empty rule into a `DENY` policy. The rule fits every request, and the sidecar proxy checks `DENY` first. So nothing gets in, and no `ALLOW` policy can change that. The short version is that "no rules" and "one empty rule" are not the same thing: the first fits nothing, and the second fits everything.

## Allow everything, then deny everything

The clearest proof of the evaluation order is to watch the widest possible `ALLOW` policy lose. So you start from a clean namespace, open it with one empty `ALLOW` rule, and then deny everything with one empty `DENY` rule.

<!-- astrona:playground:renew -->

First, remove every policy in the namespace, so only the policies in this chapter decide:

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

```text
authorizationpolicy.security.istio.io "probe-allow-shuttle-get" deleted from starfleet namespace
authorizationpolicy.security.istio.io "probe-deny-status" deleted from starfleet namespace
```

You see one line per policy that was still in the namespace. If there was none, the command prints `No resources found`.

Now open everything. This `ALLOW` policy has no `selector`, so it covers every pod in `starfleet`, and its one empty rule fits every request.

Save this as `authorizationpolicy-allow-all.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-all
  namespace: starfleet
spec:
  action: ALLOW
  rules:
  - {}
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-allow-all.yaml
```

Wait up to about a minute, then check the result:

```sh
from_shuttle $PROBE/get
from_fortio $PROBE/get
from_shuttle http://navcom:9080/ratings/0
```

```text
200 200 200 <- shuttle http://probe:8000/get
Code 200
200 200 200 <- shuttle http://navcom:9080/ratings/0
```

Every caller reaches every workload. An `ALLOW` policy exists, so default-deny is on, but the one empty rule fits every request.

With the namespace wide open, add the `DENY` policy with one empty rule. It also has no `selector`, so it covers every pod in the namespace.

Save this as `authorizationpolicy-deny-all.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: starfleet
spec:
  action: DENY
  rules:
  - {}
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-deny-all.yaml
```

Wait up to about a minute, then check the result:

```sh
from_shuttle $PROBE/get
from_fortio $PROBE/get
from_shuttle http://navcom:9080/ratings/0
```

```text
403 403 403 <- shuttle http://probe:8000/get
Code 403
403 403 403 <- shuttle http://navcom:9080/ratings/0
```

Everything is refused, while `allow-all` is still in place. The empty `DENY` rule fits every request, the sidecar proxy checks it first, and the decision ends there.

This is the emergency lockdown for a namespace, for example during a security incident. Put the same policy in the `istio-system` root namespace and it denies all traffic in every namespace of the mesh.

A lockdown is only useful if you can lift it again. Delete the `DENY` policy:

```sh
kubectl delete -f authorizationpolicy-deny-all.yaml
```

Wait up to about a minute, and `from_shuttle $PROBE/get` answers `200` again. `allow-all` can do its job once no `DENY` rule fits.

You can now read the three look-alike specs: no rules fit nothing, one empty rule fits everything, and as a `DENY`, one empty rule denies every request. That is the widest `DENY` there is. Most real `DENY` policies are much narrower, and the open question is how to make a narrow one close exactly what you meant.

## Common pitfalls

> [!WARNING]
> - **Mixing up `spec: {}` and `rules: [{}]`.** The first allows nothing. The second allows everything.
> - **Trying to open a `DENY` with `rules: [{}]` by adding `ALLOW` policies.** Nothing opens it. Delete it or narrow it.
> - **Forgetting the selector.** A policy without a `selector` covers every pod in its namespace, and in `istio-system` every pod in the mesh.
> - **Leaving an emergency lockdown in place.** Write down that you applied it, and remove it when the incident is over.
