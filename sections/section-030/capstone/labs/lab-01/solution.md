# Solution Walkthrough

Mission debrief, astronaut. Three wishes, two objects. The pass checker (`RequestAuthentication`) checks passes. The guard's list (`AuthorizationPolicy`) demands a pass and decides what each crew group may do.

---

## Step 1: Read both boarding passes

Fetch both tokens and decode the middle part, the claims:

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

Same `iss`, same `sub`. So `requestPrincipals` cannot tell these two passes apart. The `groups` claim can.

---

## Step 2: Set up the pass checker

Save this as `requestauthentication-jwt-issuer.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f requestauthentication-jwt-issuer.yaml
```

Then check the result:

```sh
kubectl -n jwtclaims-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'no token: %{http_code}\n' -X POST http://notification-service/notify
```

```text
no token: 200
```

The pass checker is on, and the service is no better protected. A caller who wants in simply shows no pass. This is `RequestAuthentication` working as designed: it checks a pass only if one is shown.

---

## Step 3: Require a pass, and split by claim

One policy, one rule per role.

Save this as `authorizationpolicy-notification-access.yaml`:

```yaml
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
    # Any astronaut with a valid pass may notify.
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
    # Only crew group1 may use the admin door.
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
kubectl apply -f authorizationpolicy-notification-access.yaml
```

Both rules carry `requestPrincipals: ["*"]`, which means "any valid pass". That is what makes a pass required. A `when` block is only a condition: it is not the same as demanding a pass.

The `groups` claim is a list. `values: ["group1"]` matches if any item in the list is `group1`. There is no special list syntax.

---

## Step 4: Prove all six requests

The tokens live in your terminal, not in the `tester` pod. So a small helper runs `curl` in the pod, and your terminal fills in the token before the command is sent:

```sh
send_signal() {
  kubectl -n jwtclaims-demo exec deploy/tester -- \
    curl -s -o /dev/null -w '%{http_code}\n' "$@"
}
printf 'no token   POST /notify: '; send_signal -X POST http://notification-service/notify
printf 'bad token  POST /notify: '; send_signal -H 'Authorization: Bearer invalid' -X POST http://notification-service/notify
printf 'plain      POST /notify: '; send_signal -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify
printf 'plain      GET  /admin:  '; send_signal -H "Authorization: Bearer $TOKEN" http://notification-service/admin
printf 'group1     GET  /admin:  '; send_signal -H "Authorization: Bearer $TOKEN_GROUP" http://notification-service/admin
printf 'no token   GET  /admin:  '; send_signal http://notification-service/admin
```

<!-- OUTPUT PENDING: expect 403, 401, 200, 403, 404, 403 in that order -->

Two different failure codes come from two different objects. A `401` is the pass checker rejecting a pass it could not verify. A `403` is the guard refusing the signal. The `404` on the `group1` line is the app answering: the mesh let it through, and that is the pass condition.

Now submit:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

---

## Common Mistakes

- **Every request returns `401`.** The `issuer` does not match the token's `iss` exactly, or the cluster cannot reach the key set address.
- **The request with no token returns `200`.** Only the `RequestAuthentication` exists. Nothing demands a pass yet.
- **The groups token is refused on `/admin`.** The claim name is wrong. Decode the token again and compare it with `request.auth.claims[groups]`.
- **A rule with `when` but no `requestPrincipals`.** A request with no pass can reach a rule you thought was guarded.
- **Selecting every workload.** If the policy has no `selector`, `booking-service` also demands a pass and the grader's `POST /book` check fails.
