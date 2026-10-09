# Other Token Places And The DENY Form

Not every request carries its JWT (JSON Web Token, a signed token with claims about the end user) in the `Authorization` header, and not every `AuthorizationPolicy` is written as `ALLOW`. Real clients and real meshes need both variations, and each one hides a trap that changes the status code you get.

This chapter changes both. First you move the token into a query parameter and see that the proxy then stops reading the header. Then you write "token required" as a `DENY` policy, which gives the same result with one important difference.

## Read the token from a query parameter

By default, the `RequestAuthentication` check looks for the token in one place: the header `Authorization: Bearer <token>`. Some clients cannot set that header, for example a link in a browser. For them, `fromParams` reads the token from a query parameter such as `?token=...`. The catch is that once you name a place, the proxy reads **only** that place.

The steps below need the `probe-jwt` `RequestAuthentication` and the `probe-require-jwt` `AuthorizationPolicy` (`ALLOW`, `requestPrincipals: ["*"]`) applied on the probe. They use the helpers you pasted when you launched the playground.

<!-- astrona:playground:renew -->

Save this as `requestauthentication-probe-token-in-query.yaml`. It has the same name, `probe-jwt`, so applying it replaces the token check you have now:

```yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: probe-jwt
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json
    fromParams:
    - token
```

Apply it:

```sh
kubectl apply -f requestauthentication-probe-token-in-query.yaml
```

Wait about a minute. Then send the token in the query, the token in the header, and a broken token in the query:

```sh
check_status "$PROBE/headers?token=$TOKEN"
check_status -H "$AUTH $TOKEN" $PROBE/headers
check_status "$PROBE/headers?token=broken"
```

```text
200 200 200 
403 403 403 
401 401 401 
```

The token in the query gets `200`. The same valid token in the header now gets `403`, not `200`. The proxy no longer reads the header at all, so it sees no token, attaches no identity, and the `AuthorizationPolicy` refuses the request. It is `403` and not `401`, because nothing was checked and found invalid. The broken token in the query is read and checked, so it gets `401`.

The same rule holds for the other place you can name. The table shows where the proxy looks for each setting:

| Setting | The proxy reads the token from |
| --- | --- |
| neither field | the `Authorization` header, after `Bearer ` |
| `fromParams: [token]` | the query parameter `?token=...`, and nothing else |
| `fromHeaders: [{name: x-jwt}]` | the header `x-jwt`, and nothing else |

Before you try the `DENY` form, put the header check back. Apply your first token check again, so the probe reads the `Authorization` header:

```sh
kubectl apply -f requestauthentication-probe.yaml
```

That file is the `probe-jwt` `RequestAuthentication` with only `issuer`, `jwksUri` and `forwardOriginalToken: true`. `kubectl apply` removes the `fromParams` field that is no longer in the file, so the token is read from the header again. Check it:

```sh
kubectl get requestauthentication probe-jwt -n starfleet -o jsonpath='{.spec.jwtRules}'; echo
```

```text
[{"forwardOriginalToken":true,"issuer":"testing@secure.istio.io","jwksUri":"https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"}]
```

The rule list no longer has `fromParams`, so the probe's proxy reads the `Authorization` header again.

## Write "token required" as DENY

The `ALLOW` policy says "allow requests that have a request principal". You can say the same thing the other way round: "refuse requests that have **no** request principal". That is a `DENY` policy with `notRequestPrincipals`.

Save this as `authorizationpolicy-probe-deny-without-token.yaml`. It has the same name, `probe-require-jwt`, so applying it replaces the `ALLOW` policy:

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
  action: DENY
  rules:
  - from:
    - source:
        notRequestPrincipals: ["*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-deny-without-token.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/probe-require-jwt configured
```

The warning comes from `istiod`, which checks the object as you apply it. A request principal only exists on HTTP requests. On a plain TCP port, the probe's proxy cannot read a token, so this `DENY` rule would refuse every TCP connection to the probe. The probe only speaks HTTP, so nothing breaks here. On a workload with TCP ports, add a `to.operation.ports` list to keep the rule on the HTTP ports.

Wait about a minute, then send the three kinds of requests:

```sh
check_status $PROBE/headers
check_status -H "$AUTH broken" $PROBE/headers
check_status -H "$AUTH $TOKEN" $PROBE/headers
```

```text
403 403 403 
401 401 401 
200 200 200 
```

The result is the same as with the `ALLOW` policy: `403`, `401`, `200`. `notRequestPrincipals: ["*"]` matches every request that has no request principal at all, and `DENY` refuses it.

The codes are the same, but the two forms change the workload in different ways. An `ALLOW` policy switches the probe to "only what a rule allows": any request that no `ALLOW` rule matches is refused. A `DENY` policy only refuses the requests it matches. It does not switch the probe to "only what a rule allows", so every request with a valid token still gets in, unless some other policy refuses it.

That makes the `DENY` form a safe "token required" layer you can put on top of other policies. It never quietly refuses a request that another `ALLOW` policy was meant to let in. That is why it is a common way to require tokens at the edge of the mesh, for example on the ingress gateway (the Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster).

You can now choose where the proxy reads a token and how a policy requires one. Name a place for the token and the proxy reads only there, so a token in the wrong place gets `403`, not `401`. Write "token required" as `DENY` with `notRequestPrincipals`, and the workload keeps every other rule it had. Together with the token check and the `ALLOW` form, these are the forms you meet most often when a task asks you to require an end user's token.

## Common pitfalls

> [!WARNING]
> - **Setting `fromParams` or `fromHeaders` and still sending `Authorization: Bearer`.** Once you name a place, the proxy reads only that place. The header is ignored, and the request gets `403`.
> - **Reading that `403` as a bad token.** A token the proxy never read cannot be bad. `401` means "read and found invalid"; `403` here means "no token seen".
> - **Writing `requestPrincipals` under `DENY`.** `DENY` with `requestPrincipals: ["*"]` refuses every request that **has** a valid token: the opposite of what you want. Use `notRequestPrincipals`.
> - **Forgetting that `DENY` beats `ALLOW`.** A `DENY` rule that matches always wins, whatever the `ALLOW` policies say.

## Your mission: Read A JWT From A Query Parameter

You can now read a token from a query parameter and require one with a `DENY` policy. The graded lab asks that the probe accept its token only from the `token` query parameter, and refuse every request without a valid token through a `DENY` policy.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-030-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-030-01-02
astrona start ats-015-playground-030-01
```
