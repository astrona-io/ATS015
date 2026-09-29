# Step-by-Step Guide: CAP015-030

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Read both tokens

```sh
export TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
export TOKEN_GROUP=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/groups-scope.jwt)
echo "$TOKEN"       | cut -d. -f2 | base64 -d 2>/dev/null; echo
echo "$TOKEN_GROUP" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
{"exp":3537391104,"groups":["group1","group2"],"iat":1537391104,"iss":"testing@secure.istio.io","scope":["scope1","scope2"],"sub":"testing@secure.istio.io"}
```

Same `iss`, same `sub` — so `requestPrincipals` cannot tell these two apart. The
claims can.

## Step 2: Validation

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > requestauthentication-jwt-issuer.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-issuer
  namespace: jwtclaims-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  jwtRules:
    - issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
YAML
kubectl apply -f requestauthentication-jwt-issuer.yaml

kubectl -n jwtclaims-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token: %{http_code}\n' -X POST http://notification-service/notify
```

```text
no token: 200
```

Validation is on, and the service is no better protected — a caller who wants in
simply omits the header. That is [`RequestAuthentication`](https://istio.io/latest/docs/reference/config/security/request_authentication/) working as designed:
it validates a token *if one is present*.

## Step 3: Require a token, and split by claim

One policy, one rule per role:

```sh
cat > authorizationpolicy-notification-access.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-access
  namespace: jwtclaims-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    # Any authenticated user may notify.
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
    # Only members of group1 may reach the admin path.
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/admin"]
      when:
        - key: request.auth.claims[groups]
          values: ["group1"]
YAML
kubectl apply -f authorizationpolicy-notification-access.yaml
```

Both rules carry `requestPrincipals: ["*"]`. Without it, the second rule could be
reached by a request with no token at all — a `when` block is a condition, not a
requirement that credentials exist.

`values: ["group1"]` against a list claim matches if any element matches. There
is no separate list syntax.

## Step 4: Prove all six

```sh
kubectl -n jwtclaims-demo exec deploy/tester -- sh -c \
  "curl -s -o /dev/null -w 'no token   /notify: %{http_code}\n' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'bad token  /notify: %{http_code}\n' -H 'Authorization: Bearer invalid' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain      /notify: %{http_code}\n' -H \"Authorization: Bearer \$TOKEN\" -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain      /admin:  %{http_code}\n' -H \"Authorization: Bearer \$TOKEN\" http://notification-service/admin;
   curl -s -o /dev/null -w 'group1     /admin:  %{http_code}\n' -H \"Authorization: Bearer \$TOKEN_GROUP\" http://notification-service/admin;
   curl -s -o /dev/null -w 'no token   /admin:  %{http_code}\n' http://notification-service/admin"
```

```text
no token   /notify: 403
bad token  /notify: 401
plain      /notify: 200
plain      /admin:  403
group1     /admin:  404
no token   /admin:  403
```

Two different failure codes from two different objects: `401` is validation
rejecting a token it could not verify, `403` is authorization refusing a request.
And `404` on the last successful line is the application answering — the mesh let
it through, which is the pass condition.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Everything is `401`.** The `issuer` does not match `iss` exactly, or the
  cluster cannot reach the JWKS URL.
- **The tokenless request is `200`.** Only the `RequestAuthentication` exists.
- **The groups token is refused on `/admin`.** The claim name is wrong. Check
  what the proxy compiled:
  `istioctl proxy-config listener deploy/notification-service-v1 -n jwtclaims-demo -o json | grep -i 'request.auth.claims' -A3`.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [AuthorizationPolicy API](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Source) — `action`, `rules`, `from`, `to`, `when` and `targetRefs`
- [RequestAuthentication API](https://istio.io/latest/docs/reference/config/security/request_authentication/) — JWT issuers, JWKS and what it does not do
- [Authorization with JWT](https://istio.io/latest/docs/tasks/security/authentication/jwt-route/) — validating tokens and authorizing on their claims
- [AuthorizationPolicy actions](https://istio.io/latest/docs/reference/config/security/authorization-policy/#AuthorizationPolicy-Action) — how ALLOW, DENY and AUDIT combine and which wins
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
