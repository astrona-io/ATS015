# Require A Claim

A valid token says who the user is. Its claims say what the user is, for example which groups they belong to. In this part you let only members of one group reach the probe, and you learn the four rules that decide when a `when` condition fits.

## Only group1 may pass

Start with a real rule and watch it decide. The two sample tokens have the same principal, so only a claim can tell them apart.

### Write the rule

This policy allows a request only if it carries a valid token from the sample user **and** that token's `groups` claim contains `group1`.

<!-- astrona:playground:renew -->

If your terminal is new, paste the helpers first:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
GROUPS_TOKEN=$(curl -s $SAMPLES_URL/groups-scope.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

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
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

```text
authorizationpolicy.security.istio.io/probe-require-jwt created
```

Wait about a minute before you test. `istiod`, Istio's control plane, sends the new configuration to the probe's sidecar proxy within seconds, but connections that are already open keep the old configuration for a while.

### Test three callers

Send requests with the demo token, with the groups token, and with no token:

```sh
check_status -H "$AUTH $TOKEN" $PROBE/headers
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers
check_status $PROBE/headers
```

```text
403 403 403 
200 200 200 
403 403 403 
```

The demo token is valid, but it has no `groups` claim, so the `when` condition cannot fit: `403`. The groups token fits both the principal and the claim: `200`. A request with no token has no principal and no claims: `403`.

If you see a mix such as `200 403 403`, the change is still on its way. Wait half a minute and run the checks again.

## How a `when` condition fits

Now the general rule. A `when` entry has a `key`, one of the `request.auth` attributes, and either `values` or `notValues`. That is the whole block. Four rules decide when it fits.

### The four combination rules

```text
   values inside one entry       OR     values: ["group1", "group3"]
                                        → a token with either one fits

   several when entries          AND    two entries
                                        → both must fit

   when + from + to              AND    when is one part of a rule
                                        → every part must fit

   a list claim                  ANY    groups: ["group1", "group2"] in the token
                                        → fits if any item is in values
```

The last rule is where people look for syntax that does not exist. There is no `contains` and no special list form. `values: ["group1"]` against a token whose `groups` is a list already means "does any item equal `group1`". You write a single-value claim and a list claim the same way. Only the token is different.

Put the first and the last rule together: `values: ["group1", "group3"]` against `groups: ["group2", "group3"]` fits, because one value appears in the list. It is an overlap test. To say "must be in **both** groups", write two `when` entries, because entries are combined with AND.

## A claim no token has

The most confusing result in this module is a `403` for a token you know is valid. See it once on purpose.

### Require scope3

The groups token has `scope: [scope1, scope2]`. This rule asks for `scope3`, which no sample token has. Save this as `authorizationpolicy-probe-require-jwt.yaml` (it replaces the group rule, because it has the same name):

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
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[scope]
      values: ["scope3"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-require-jwt.yaml
```

Wait about a minute, then check the result with the groups token:

```sh
check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers
```

```text
403 403 403 
```

A perfectly valid token is refused with **`403`**, not `401`. The JWT filter accepted the token. The authorization filter refused it, because no rule fits. A `401` would mean the token itself is bad.

When a valid token gets `403`, decode it with `cut -d. -f2 | base64 -d` and compare its claims with the `when` block, letter by letter.

Clean up before you go on:

```sh
kubectl delete authorizationpolicy probe-require-jwt -n starfleet
```

## Common pitfalls

> [!WARNING]
> - **Reading several `when` entries as OR.** Entries are combined with AND. Only the values inside one entry are combined with OR.
> - **Expecting `values: ["a", "b"]` to need both.** It needs either one. Two requirements need two entries.
> - **Looking for a list operator.** `values: ["group1"]` already matches any item of a list claim.
> - **Reading a `403` as "bad token".** A bad token gets `401` from the JWT filter. A `403` means the token was fine and no rule fit.
> - **Testing too fast.** Connections that were already open keep the old configuration for a while. If the result looks old, wait and run it again.

> *A `when` condition is one AND part of a rule. Values in one entry are OR, entries are AND, and a list claim fits if any item matches.*
