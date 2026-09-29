# Step-by-Step Guide: LAB015-030-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Get a token and look inside it

```sh
export TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
```

A JWT payload is base64url-encoded JSON, not encryption — no key needed to read
it. `iss` is what your `issuer` field must match exactly.

Confirm the service is currently open:

```sh
kubectl -n jwt-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token: %{http_code}\n' -X POST http://notification-service/notify
```

```text
no token: 200
```

## Step 2: Configure validation

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > requestauthentication-jwt-demo.yaml <<'YAML'
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
YAML
kubectl apply -f requestauthentication-jwt-demo.yaml
```

Test all three cases now, before adding anything else:

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

Validation works — the `401` proves the proxy fetched the key set and checked a
signature. And the service is no better protected than before: the tokenless call
still returns `200`, because [`RequestAuthentication`](https://istio.io/latest/docs/reference/config/security/request_authentication/) validates a token *if one is
present* and has no opinion about a request that carries none.

## Step 3: Require a token

The requirement is an authorization decision, so it is an [`AuthorizationPolicy`](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source):

```sh
cat > authorizationpolicy-require-jwt.yaml <<'YAML'
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
YAML
kubectl apply -f authorizationpolicy-require-jwt.yaml
```

A request principal is `<issuer>/<subject>`; `["*"]` means any valid token. This
is an `ALLOW` policy selecting the workload, so everything it does not permit is
now denied — and a tokenless request has no request principal to match.

## Step 4: Prove all three

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

Two failures from two objects: `401` is validation rejecting a token it could not
verify; `403` is authorization refusing a well-formed request that had no token
to show.

You can read the issuer back out of the proxy to check for a typo:

```sh
istioctl proxy-config listener deploy/notification-service-v1 -n jwt-demo -o json \
  | grep -i 'jwt_authn\|issuer' | head
```

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Every request is `401`, including the valid one.** The `issuer` does not
  match `iss` exactly (a trailing slash is the usual culprit), or the cluster
  cannot reach the JWKS URL.
- **The tokenless request is `200`.** Only the `RequestAuthentication` exists.
- **The tokenless request is `401`.** Something is rejecting it at validation
  rather than at authorization — check that your `AuthorizationPolicy` uses
  `requestPrincipals` and not something else.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [RequestAuthentication API](https://istio.io/latest/docs/reference/config/security/request_authentication/) — JWT issuers, JWKS and what it does not do
- [Authorization with JWT](https://istio.io/latest/docs/tasks/security/authentication/jwt-route/) — validating tokens and authorizing on their claims
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
