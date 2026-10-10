# Negative Fields In A DENY Policy

Most fields in a rule say what a request **is**: this method, this path, this caller. Each of them has a twin that starts with `not`: `notMethods`, `notPaths`, `notPrincipals`, `notNamespaces` and more. They are the usual way to say "everything except". Inside a `DENY`, though, they form a double negative, and a quick reader often gets the meaning backwards.

This chapter writes a `DENY` that lets only one method through, then gives you a simple habit that stops you from misreading a negative field. It ends with a pattern for refusing callers that have no identity at all.

## Deny everything except reads

A concrete case makes the double negative easy to see. You write a `DENY` policy for the whole namespace that lets only `GET` through. Before you apply it, say out loud what it will do.

<!-- astrona:playground:renew -->

Remove every policy in the namespace first, so only the policy in this chapter decides:

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

The new policy has no `selector`, so it covers every pod in `starfleet`. Save this as `authorizationpolicy-deny-non-get.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-non-get
  namespace: starfleet
spec:
  action: DENY
  rules:
  - to:
    - operation:
        notMethods: ["GET"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-deny-non-get.yaml
```

Wait up to about a minute, then send a read and three writes, two from the shuttle and one from fortio:

```sh
from_shuttle $PROBE/get
from_shuttle -X POST $PROBE/post
from_shuttle -X DELETE $PROBE/delete
from_fortio -X POST $PROBE/post
```

```text
200 200 200 <- shuttle http://probe:8000/get
403 403 403 <- shuttle -X POST http://probe:8000/post
403 403 403 <- shuttle -X DELETE http://probe:8000/delete
Code 403
```

`notMethods: ["GET"]` fits every request whose method is **not** `GET`. The action is `DENY`, so all of those are refused, from every caller, and only reads get through. Because the policy has no `selector`, `bridge`, `scout` and every other workload in the namespace are now read-only too.

When you are done, remove it with `kubectl delete -f authorizationpolicy-deny-non-get.yaml`.

## Read the sentence, starting with the action

That policy behaved as written, but it is easy to read wrongly at a glance. The safe way to read any negative field is the same every time: read the policy as one sentence, in this order: the action, then the field, then the values.

```mermaid
flowchart LR
    A["action: DENY"] -->|"requests whose path"| B["notPaths: /health"]
    B -->|"means"| C["refuse every path except /health"]
```

The diagram shows a `DENY` with `notPaths: ["/health"]`, read out loud. At a glance it looks like a rule *about* `/health`. Read as a sentence, it denies every path on the workload except one.

The same fields inside an `ALLOW` mean the opposite: "let in every path except `/health`". The YAML gives no hint which meaning the author wanted, so say the sentence before you apply it. If the sentence surprises you, the policy would have surprised you too. Here are the common cases, each read as a sentence:

| Policy | The sentence |
| --- | --- |
| `DENY` + `notMethods: ["GET"]` | refuse every request that is not a `GET` |
| `DENY` + `notPaths: ["/health"]` | refuse every path except `/health` |
| `ALLOW` + `notPaths: ["/health"]` | let in every path except `/health` |
| `DENY` + `notPrincipals: ["*"]` | refuse every request that has no verified identity |

## Callers without an identity

The last row of that table is a pattern worth knowing. `principals: ["*"]` fits any caller that presented a valid mTLS certificate. So `notPrincipals: ["*"]` fits any caller that presented **none**, such as the `drifter` pod in `outpost`, which has no sidecar proxy and sends plain text. Inside a `DENY`, it refuses every request without a verified identity.

In `starfleet` you cannot see this with the drifter. The `STRICT` `PeerAuthentication` already makes the sidecar proxies refuse its plain-text connections at the TLS handshake, before any `AuthorizationPolicy` is checked. The pattern matters on workloads that still accept plain text. We checked it on a test system with the probe switched to `PERMISSIVE`: with `DENY` + `notPrincipals: ["*"]` in place, the drifter got `403 RBAC: access denied`, and the shuttle still got `200`.

Whenever a rule depends on what happens when a value is missing, as here, test it with a real caller rather than reasoning about it. And where you can say the same thing with a positive field, do.

A negative field inside a `DENY` denies everything except its list, and reading the policy as a sentence that starts with the action keeps you from reading it backwards. So far, though, every `DENY` you wrote started blocking the moment you applied it. The open question is how to try a rule on real requests before it can break anything.

## Common pitfalls

> [!WARNING]
> - **Reading a negative `DENY` as an allow list.** `DENY` + `notPaths` refuses everything the list does **not** name. It does not let that list in.
> - **Forgetting the scope of a policy without a selector.** `deny-non-get` made every workload in the namespace read-only, not only the probe.
> - **Using `notMethods` when you meant `methods`.** `DENY` + `methods: ["POST"]` denies one method; `DENY` + `notMethods: ["POST"]` denies every other method.
> - **Expecting a negative field to see a caller that never reached the authorization check.** Under `STRICT`, a plain-text caller is turned away at the TLS handshake first.
