# Solution Walkthrough

Protecting a service from requests without a token always takes two objects. A `RequestAuthentication` checks tokens, and an `AuthorizationPolicy` makes one required. With only the first, the service is as open as before.

---

## Step 1: Get a token and look inside it

Download the demo token and decode its middle part, the payload:

```sh
export TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
```

A JWT payload is base64-encoded text, not encryption, so no key is needed to read it. `iss` is the value your `issuer` field must match exactly. If `$TOKEN` is empty, your machine cannot reach `raw.githubusercontent.com`.

Confirm the service is open today:

```sh
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token: %{http_code}\n' -X POST http://notification-service/notify
```

```text
no token: 200
```

## Step 2: Check tokens

Save this as `requestauthentication-jwt-demo.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-demo
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  jwtRules:
    - issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
```

Apply it:

```sh
kubectl apply -f requestauthentication-jwt-demo.yaml
```

Then test all three cases, before you add anything else. Wait about a minute first: the proxies keep old connections open for a while, and those still follow the old rules.

```sh
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token:  %{http_code}\n' -X POST http://notification-service/notify
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'bad token: %{http_code}\n' -H "Authorization: Bearer invalid" -X POST http://notification-service/notify
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'valid:     %{http_code}\n' -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify
```

```text
no token:  200
bad token: 401
valid:     200
```

The token check works: the `401` proves the proxy had the keys and checked a signature. But the service is no better protected than before. The request with no token still gets `200`, because a `RequestAuthentication` checks a token *if one is there* and has no opinion about a request that carries none.

## Step 3: Require a token

Requiring a token is a rule about which requests are allowed, so it is an `AuthorizationPolicy`.

Save this as `authorizationpolicy-require-jwt.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-require-jwt.yaml
```

A request principal is `<issuer>/<subject>`, and `["*"]` means any valid token. This is an `ALLOW` policy on the workload, so everything it does not allow is now refused. A request with no token has no request principal to match.

## Step 4: Prove all three

Wait about a minute, then send the three requests again:

```sh
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token:  %{http_code}\n' -X POST http://notification-service/notify
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'bad token: %{http_code}\n' -H "Authorization: Bearer invalid" -X POST http://notification-service/notify
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'valid:     %{http_code}\n' -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify
```

```text
no token:  403
bad token: 401
valid:     200
```

Two failures from two objects. `401` is the `RequestAuthentication` rejecting a token it could not verify. `403` is the `AuthorizationPolicy` refusing a request that had no token to show.

Check that the service next door is still open:

```sh
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'booking: %{http_code}\n' -X POST http://booking-service/book
```

```text
booking: 200
```

You can also read the issuer back out of the proxy, to catch a typo:

```sh
istioctl proxy-config listener deploy/notification-service-v1 -n jwt-demo -o json \
  | grep -o '"envoy.filters.http.jwt_authn"\|"issuer": "[^"]*"\|"localJwks"' | sort | uniq -c
```

```text
  12 "envoy.filters.http.jwt_authn"
   4 "issuer": "testing@secure.istio.io"
   4 "localJwks"
```

The proxy has the token filter, the exact issuer string, and `localJwks`: the public keys that `istiod` downloaded and put into the proxy's configuration. The counts depend on how the proxy's listeners are built, so do not worry about them. What matters is that all three lines are there.

Now submit:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

---

## Common Mistakes

- **Only the `RequestAuthentication`.** The request with no token gets `200`. The token check validates, it does not require.
- **Every request gets `401`, including the valid one.** The `issuer` does not match `iss` exactly (a trailing slash is the usual cause), or `istiod` cannot reach the JWKS address.
- **The request with no token gets `401`.** Something is rejecting it at the token check instead of at authorization. The requirement must come from an `AuthorizationPolicy` with `requestPrincipals`.
- **No `selector`, or the wrong one.** Without a `selector`, the policy covers every workload in `jwt-demo`, and `booking-service` starts refusing requests without a token.
- **Testing too fast.** Right after `kubectl apply`, old connections can still follow the old rules. Wait about a minute and send the requests again.
