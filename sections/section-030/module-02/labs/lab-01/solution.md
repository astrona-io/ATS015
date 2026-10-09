# Solution Walkthrough

Mission debrief, astronaut. Both tokens carry the same principal, so `requestPrincipals` alone cannot tell an ordinary user from an administrator. Only the `groups` claim can. One policy with one rule per role does the job.

---

## Step 1: Read both tokens

Download the two sample tokens, then decode the middle part (the payload) of each one:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
GROUPS_TOKEN=$(curl -s $SAMPLES_URL/groups-scope.jwt)

echo "$TOKEN"        | cut -d. -f2 | base64 -d 2>/dev/null; echo
echo "$GROUPS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
{"exp":3537391104,"groups":["group1","group2"],"iat":1537391104,"iss":"testing@secure.istio.io","scope":["scope1","scope2"],"sub":"testing@secure.istio.io"}
```

Both share `iss` and `sub`, so both give the **same principal**, `testing@secure.istio.io/testing@secure.istio.io`. The claim name you need is `groups`, and it is a list.

## Step 2: Write one policy with one rule per role

Rule 1 lets any valid token `POST /notify`. Rule 2 lets a valid token `GET /admin` only if its `groups` claim contains `group1`. Rules in one policy are combined with OR; the parts inside one rule are combined with AND.

Save this as `authorizationpolicy-jwt-claims.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-jwt-claims.yaml
```

```text
authorizationpolicy.security.istio.io/jwt-claims created
```

Both rules carry `requestPrincipals: ["*"]`, so each one plainly needs a valid token. The task asks for that, and the grader checks it.

`values: ["group1"]` against a list claim fits if **any** item matches. There is no `contains` operator, and none is needed.

## Step 3: Prove all five outcomes

Wait about a minute after the apply, so that connections opened before it have closed. Then send each request from `tester`. The token variables are expanded by your own shell before `kubectl` runs, because the whole `sh -c` string is in double quotes:

```sh
kubectl -n jwtclaims-demo exec deploy/tester -- sh -c \
  "curl -s -o /dev/null -w 'no token  /notify: %{http_code}\n' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain     /notify: %{http_code}\n' -H 'Authorization: Bearer $TOKEN' -X POST http://notification-service/notify;
   curl -s -o /dev/null -w 'plain     /admin:  %{http_code}\n' -H 'Authorization: Bearer $TOKEN' http://notification-service/admin;
   curl -s -o /dev/null -w 'group1    /admin:  %{http_code}\n' -H 'Authorization: Bearer $GROUPS_TOKEN' http://notification-service/admin;
   curl -s -o /dev/null -w 'no token  /admin:  %{http_code}\n' http://notification-service/admin"
```

```text
no token  /notify: 403
plain     /notify: 200
plain     /admin:  403
group1    /admin:  200
no token  /admin:  403
```

The demo token is refused at `/admin` because it has no `groups` claim, so the second rule's `when` cannot fit. Under `ALLOW`, a missing claim fails closed. The groups token gets through, and the app answers. Any status other than `403` means the mesh let the request pass.

If you see an old result, wait half a minute and send the requests again. Connections that were already open keep the old orders for a while.

Now submit:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

---

## Common Mistakes

- **Everything is `403`.** The claim name is probably wrong. Compare it with the decoded payload, then check what the proxy holds: `istioctl proxy-config listener deploy/notification-service-v1 -n jwtclaims-demo -o json | grep -A3 '"key": "payload"' | grep '"key"' | grep -v payload | tr -d ' ' | sort -u`. It prints the claim names the proxy compares, for example `"key":"groups"`.
- **A rule with `when` but no `requestPrincipals`.** The traffic may still look right, but the grader requires every rule to name a valid token.
- **Every call is `401`.** The token variables did not expand. In single quotes they reach the pod as plain text, which looks like a bad token.
- **Changing the `RequestAuthentication`.** It was correct. The grader checks that `jwt-demo` is unchanged.
