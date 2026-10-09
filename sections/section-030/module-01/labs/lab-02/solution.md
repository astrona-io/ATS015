# Solution Walkthrough

Two small objects do the whole job. The `RequestAuthentication` says where to find the token (`fromParams`), and the `DENY` policy refuses every request that arrives without a valid one.

---

## Step 1: Get the token and a helper

Download the demo token and define a helper that sends one request from the `shuttle` pod and prints its status code:

```sh
TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
PROBE=http://probe:8000/headers
check_once() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" "$@"; }
```

Confirm the probe is open today, with and without a token:

```sh
check_once $PROBE
check_once "$PROBE?token=$TOKEN"
```

```text
200
200
```

## Step 2: Read the token from the query parameter

Save this as `requestauthentication-probe-jwt.yaml`:

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
kubectl apply -f requestauthentication-probe-jwt.yaml
```

`fromParams: [token]` tells the probe's proxy to look for the token in `?token=...`. Once you name a place, the proxy reads **only** that place, so the `Authorization` header is no longer read.

## Step 3: Require the token with DENY

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
  action: DENY
  rules:
  - from:
    - source:
        notRequestPrincipals: ["*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/probe-require-jwt created
```

The warning is expected. A request principal only exists on HTTP requests, so on a plain TCP port this `DENY` rule would refuse everything. The probe only speaks HTTP, so nothing breaks here.

`notRequestPrincipals: ["*"]` matches every request with no request principal, that is, every request without a valid token. `DENY` refuses those. Unlike an `ALLOW` policy, it does not switch the probe to "only what is on the list", so the `ALLOW` policies other teams add later keep working.

## Step 4: Prove all four

Wait about a minute: the proxies keep old connections open for a while, and those still follow the old rules. Then send the four requests:

```sh
check_once "$PROBE?token=$TOKEN"
check_once -H "Authorization: Bearer $TOKEN" $PROBE
check_once "$PROBE?token=bad"
check_once $PROBE
```

```text
200
403
401
403
```

The header token gets `403`, not `200` and not `401`. The proxy never read it, so it attached no request principal, and the `DENY` policy refused the request. A `401` only appears when a token was read and found invalid, as with `?token=bad`.

Now submit:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-02
```

---

## Common Mistakes

- **Writing `requestPrincipals` under `DENY`.** That refuses every request that **has** a valid token: the opposite of the task. Use `notRequestPrincipals`.
- **Adding an `ALLOW` policy as well.** The task asks for the `DENY` form only, and the grader checks that no `ALLOW` policy exists.
- **Expecting the header token to still work.** With `fromParams` set, the header is ignored, and the grader checks that a token in the header gets `403`.
- **Testing too fast.** Right after `kubectl apply`, old connections can still follow the old rules. If the header token still gets `200`, wait and send it again.
