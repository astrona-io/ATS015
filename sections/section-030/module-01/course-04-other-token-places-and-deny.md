# Other Token Places And The DENY Form

Astronaut, not every signal carries its token in the `Authorization` header, and not every guard's list is written as `ALLOW`. This part changes both. First you move the token into a query parameter and see that the proxy then stops reading the header. Then you write "token required" as a `DENY` policy, which gives the same result with one important difference.

## Read the token from a query parameter

By default, the pass checker looks for the token in one place: the header `Authorization: Bearer <token>`. Some clients cannot set that header, for example a link in a browser. For them, `fromParams` reads the token from a query parameter such as `?token=...`. The catch is that once you name a place, the proxy reads **only** that place.

### See it in your playground

These steps need the `probe-jwt` `RequestAuthentication` and the `probe-require-jwt` `AuthorizationPolicy` (`ALLOW`, `requestPrincipals: ["*"]`) applied on the probe. They use the helpers you pasted at the start of the module.

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

The token in the query gets `200`. The same valid token in the header now gets `403`, not `200`. The proxy no longer reads the header at all, so it sees no token, attaches no name, and the guard's list refuses the signal. It is `403` and not `401`, because nothing was checked and found false. The broken token in the query is read and checked, so it gets `401`.

### Where a token can come from

| Setting | The proxy reads the token from |
| --- | --- |
| neither field | the `Authorization` header, after `Bearer ` |
| `fromParams: [token]` | the query parameter `?token=...`, and nothing else |
| `fromHeaders: [{name: x-jwt}]` | the header `x-jwt`, and nothing else |

### Put the header check back

Apply your first token check again, so the probe reads the `Authorization` header:

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

## Write "token required" as DENY

The `ALLOW` policy says "let in signals that have a name". You can say the same thing the other way round: "refuse signals that have **no** name". That is a `DENY` policy with `notRequestPrincipals`.

### See it in your playground

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

The warning comes from `istiod`, which checks the object as you apply it. A request principal only exists on HTTP signals. On a plain TCP channel, the probe's proxy cannot read a token, so this `DENY` rule would refuse every TCP signal to the probe. The probe only speaks HTTP, so nothing breaks here. On a ship with TCP channels, add a `to.operation.ports` list to keep the rule on the HTTP channels.

Wait about a minute, then send the three kinds of signals:

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

The result is the same as with the `ALLOW` policy: `403`, `401`, `200`. `notRequestPrincipals: ["*"]` matches every signal that has no request principal at all, and `DENY` refuses it.

### The one difference

The two forms give the same codes here, but they change the ship in different ways:

- An **`ALLOW`** policy switches the probe to "only what is on the list". Any signal that no `ALLOW` rule matches is refused.
- A **`DENY`** policy only removes signals. It does not switch the probe to "only what is on the list". Every signal with a valid token still gets in, unless some other policy refuses it.

So the `DENY` form is a safe "token required" layer you can put on top of other policies. It never quietly refuses a signal that another `ALLOW` policy was meant to let in. That is why it is a common way to require tokens at the edge of the mesh, for example on the ingress gateway.

## Common pitfalls

> [!WARNING]
> - **Setting `fromParams` or `fromHeaders` and still sending `Authorization: Bearer`.** Once you name a place, the proxy reads only that place. The header is ignored, and the signal gets `403`.
> - **Reading that `403` as a bad token.** A token the proxy never read cannot be bad. `401` means "read and found false"; `403` here means "no token seen".
> - **Writing `requestPrincipals` under `DENY`.** `DENY` with `requestPrincipals: ["*"]` refuses every signal that **has** a valid token: the opposite of what you want. Use `notRequestPrincipals`.
> - **Forgetting that `DENY` beats `ALLOW`.** A `DENY` rule that matches always wins, whatever the `ALLOW` policies say.

> *Name a place for the token and the proxy reads only there; write "token required" as `DENY` and the ship keeps every other rule it had.*

## Your mission: Take The Token From The Query String

You can now read a token from a query parameter and require one with a `DENY` policy. Now prove it in a graded mission: the probe must accept its token only from the `token` query parameter, and refuse every signal without a valid token through a `DENY` policy.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-030-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-030/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-030-01-02
astrona start ats-015-playground-030-01
```
