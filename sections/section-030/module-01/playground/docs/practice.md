# Practice: Authenticate End Users With JWT

Two exam-style missions for this playground, astronaut. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solutions use them.

Try each task on your own first, then open the solution. If you already
applied objects while reading the module, start task 1 from a clean planet:

```bash
kubectl delete requestauthentication,authorizationpolicy --all -n starfleet
```

## Task 1: no token, no entry

> In namespace `starfleet`, check tokens from the issuer
> `testing@secure.istio.io` on the `probe`. Its keys are at
> `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json`.
> Signals to the probe with no token must be refused with `403`, signals with
> a broken token with `401`, and signals with the demo token must get `200`.
> No other ship may be affected.

<details><summary>Solution</summary>

Two objects, in this order: first the one that checks tokens, then the one
that requires them. The other order refuses every signal, even good ones.

Save this as `requestauthentication-probe.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata: {name: probe-jwt, namespace: starfleet}
spec:
  selector: {matchLabels: {app: probe}}
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json
```

Apply it:

```bash
kubectl apply -f requestauthentication-probe.yaml
```

Save this as `authorizationpolicy-probe-require-jwt.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: probe-require-jwt, namespace: starfleet}
spec:
  selector: {matchLabels: {app: probe}}
  action: ALLOW
  rules:
  - from:
    - source: {requestPrincipals: ["*"]}
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Then check the result, about a minute later:

```bash
check_status $PROBE/headers
check_status -H "$AUTH broken" $PROBE/headers
check_status -H "$AUTH $TOKEN" $PROBE/headers
check_status http://cargo:9080/details/0
```

```text
403 403 403 
401 401 401 
200 200 200 
200 200 200 
```

The `selector` keeps both objects on the probe, so `cargo` still answers
without a token.

</details>

## Task 2: one astronaut only

> Keep the `RequestAuthentication` from task 1. Change the policy so the probe
> lets in **only** the user whose request principal is
> `testing@secure.istio.io/testing@secure.istio.io`. Any other valid user, and
> any signal without a token, must be refused.

<details><summary>Solution</summary>

A request principal is the token's `iss` claim, a slash, and its `sub` claim.
The demo token has `testing@secure.istio.io` in both.

Save this as `authorizationpolicy-probe-require-jwt.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: probe-require-jwt, namespace: starfleet}
spec:
  selector: {matchLabels: {app: probe}}
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Then check the result, about a minute later:

```bash
check_status -H "$AUTH $TOKEN" $PROBE/headers
check_status $PROBE/headers
```

```text
200 200 200 
403 403 403 
```

Compare it with `requestPrincipals: ["*"]` from task 1. The star lets in any
user with a valid token; the full value lets in one user only.

</details>
