# Practice: Authorize On JWT Claims

Two exam-style missions for this playground, astronaut. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solutions use them.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

The `probe-jwt` `RequestAuthentication` is already in place, so tokens are
checked. Your job in both tasks is the `AuthorizationPolicy`.

## Task 1: one claim, one value

> Only requests with a token that contains the claim **`foo: bar`** may reach
> `probe` in namespace `starfleet`. Requests without a token must be denied.

<details><summary>Solution</summary>

A `when` condition on `request.auth.claims[foo]` does the work. A request
without a token has no claims at all, so it cannot match and is denied.

Save this as `authorizationpolicy-probe-require-jwt.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: probe-require-jwt, namespace: starfleet}
spec:
  selector: {matchLabels: {app: probe}}
  action: ALLOW
  rules:
  - when:
    - key: request.auth.claims[foo]
      values: ["bar"]
```

Apply it:

```bash
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Wait about a minute, then check the result:

```bash
check_status -H "$AUTH $TOKEN" $PROBE/headers          # 200 200 200  (demo token: foo=bar)
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers   # 403 403 403  (no foo claim)
check_status $PROBE/headers                            # 403 403 403  (no token: no claims)
```

```text
200 200 200 
403 403 403 
403 403 403 
```

Adding `requestPrincipals: ["*"]` under `from.source` gives the same result.
It makes the "a valid token is needed" part easy to read.

</details>

## Task 2: a public path and a group-only path

> On `probe` in namespace `starfleet`:
>
> - anyone, with or without a token, may read `/headers`;
> - any valid token may `GET /get`;
> - only a token whose `groups` claim contains `group1` may reach
>   `/anything/admin`.
>
> Use one `AuthorizationPolicy` named `probe-access`.

<details><summary>Solution</summary>

One policy, one rule per role. Rules are combined with OR, so each rule is a
complete statement of who may do what.

Save this as `authorizationpolicy-probe-access.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: probe-access, namespace: starfleet}
spec:
  selector: {matchLabels: {app: probe}}
  action: ALLOW
  rules:
  - to:
    - operation: {paths: ["/headers"]}
  - from:
    - source: {requestPrincipals: ["*"]}
    to:
    - operation: {methods: ["GET"], paths: ["/get"]}
  - from:
    - source: {requestPrincipals: ["*"]}
    to:
    - operation: {paths: ["/anything/admin"]}
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
```

Apply it (delete the Task 1 policy first, so it does not add extra rules):

```bash
kubectl delete authorizationpolicy probe-require-jwt -n starfleet --ignore-not-found
kubectl apply -f authorizationpolicy-probe-access.yaml
```

Wait about a minute, then check the result:

```bash
check_status $PROBE/headers                                        # 200 200 200
check_status $PROBE/get                                            # 403 403 403
check_status -H "$AUTH $TOKEN" $PROBE/get                          # 200 200 200
check_status -H "$AUTH $TOKEN" $PROBE/anything/admin               # 403 403 403
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/anything/admin        # 200 200 200
```

```text
200 200 200 
403 403 403 
200 200 200 
403 403 403 
200 200 200 
```

The first rule has no `from`, so it matches any caller, with or without a
token. Put `requestPrincipals` in that rule and `/headers` stops being public.

</details>
