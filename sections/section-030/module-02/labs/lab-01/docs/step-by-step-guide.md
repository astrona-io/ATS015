# Step-by-Step Guide: LAB015-030-02

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

Both share `iss` and `sub`, so both produce the **same request principal** —
`requestPrincipals` cannot tell them apart. The claims are the only difference,
which is exactly what claim rules are for.

## Step 2: One policy, one rule per role

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: jwt-claims
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
```

Both rules carry `requestPrincipals: ["*"]`. A `when` block alone does not
require a token — it is a condition over whatever attributes exist, and a
tokenless request simply has none. Pairing the two is what guarantees a valid
token was present before the claim is consulted.

`values: ["group1"]` against a list claim matches if **any** element matches.
There is no `contains` operator and none is needed.

## Step 3: Prove all four outcomes

```sh
kubectl -n jwtclaims-demo exec deploy/tester -- sh -c \
  "curl -s -o /dev/null -w 'no token  /notify: %{http_code}\n' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain     /notify: %{http_code}\n' -H 'Authorization: Bearer $TOKEN' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain     /admin:  %{http_code}\n' -H 'Authorization: Bearer $TOKEN' http://notification-service/admin;
   curl -s -o /dev/null -w 'group1    /admin:  %{http_code}\n' -H 'Authorization: Bearer $TOKEN_GROUP' http://notification-service/admin"
```

```text
no token  /notify: 403
plain     /notify: 200
plain     /admin:  403
group1    /admin:  404
```

The plain token is refused at `/admin` because it has no `groups` claim, so the
second rule's `when` cannot hold — a missing claim fails **closed** under
`ALLOW`. The group token is allowed through and then gets `404`, because the
application has no such handler. `404` is the app answering; `403` is the mesh
refusing.

Note the double quotes around the inner `sh -c` string. In single quotes the
`$TOKEN` variables never expand and every call looks like a bad token.

## Step 4: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Everything is `403`.** The claim name is probably wrong. Confirm it against
  the decoded payload, then check what the proxy compiled:
  `istioctl proxy-config listener deploy/notification-service-v1 -n jwtclaims-demo -o json | grep -i 'request.auth.claims' -A3`.
- **A tokenless request reaches `/admin`.** A rule has a `when` but no
  `requestPrincipals`.
- **Every call is `401`.** The variables did not expand — check the quoting.
