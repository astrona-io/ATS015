# Solution Walkthrough

Mission debrief, astronaut. The policy had two faults, and neither one gave an error. The public rule asked for a token, so `/headers` stopped being public. The admin rule compared a claim named `group`, which no token has.

---

## Step 1: Get the tokens and see the failures

Download the two sample tokens and define a small helper that sends one signal from the shuttle and prints the status code:

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
GROUPS_TOKEN=$(curl -s $SAMPLES_URL/groups-scope.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
send_signal() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" "$@"; }
```

Send a signal to the public path without a token, and one to the admin path with the groups token:

```sh
send_signal $PROBE/headers
send_signal -H "$AUTH $GROUPS_TOKEN" $PROBE/anything/admin
```

```text
403
403
```

Both are refused with `403`. That is the authorization filter saying "no rule fits", not a bad token: a bad token would get `401`.

## Step 2: Read the policy

```sh
kubectl get authorizationpolicy probe-access -n starfleet -o yaml
```

```text
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals:
        - '*'
    to:
    - operation:
        paths:
        - /headers
  - from:
    - source:
        requestPrincipals:
        - '*'
    to:
    - operation:
        methods:
        - GET
        paths:
        - /get
  - from:
    - source:
        requestPrincipals:
        - '*'
    to:
    - operation:
        paths:
        - /anything/admin
    when:
    - key: request.auth.claims[group]
      values:
      - group1
  selector:
    matchLabels:
      app: probe
```

We show only the `spec`; the real output also has the `metadata` block.

Look at the first rule. Its `from` and `to` sit in **one** rule, so they are combined with AND: "`/headers` **and** a valid token". A public path must be its own rule with no `from`.

## Step 3: Compare the admin rule with the token

Read the claim names the probe's communications officer actually compares. Inside the proxy, each claim sits under the token's `payload`, so this command picks out the names that follow it:

```sh
istioctl proxy-config listener deploy/probe-v1 -n starfleet -o json \
  | grep -A3 '"key": "payload"' | grep '"key"' | grep -v payload | tr -d ' ' | sort -u
```

```text
"key":"group"
"key":"iss"
"key":"sub"
```

`iss` and `sub` come from `requestPrincipals: ["*"]`. `group` comes from the admin rule's `when` block.

Now decode the groups token:

```sh
echo "$GROUPS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null; echo
```

```text
{"exp":3537391104,"groups":["group1","group2"],"iat":1537391104,"iss":"testing@secure.istio.io","scope":["scope1","scope2"],"sub":"testing@secure.istio.io"}
```

The token says `groups`. The rule says `group`. A rule on a claim the token does not have never fits, so under `ALLOW` the request is refused.

## Step 4: Fix the policy

Save this as `authorizationpolicy-probe-access.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-access
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - to:
    - operation:
        paths: ["/headers"]
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get"]
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        paths: ["/anything/admin"]
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-access.yaml
```

```text
authorizationpolicy.security.istio.io/probe-access configured
```

## Step 5: Prove it works

Wait about a minute, so that connections opened before the change have closed. Then send every signal the task lists:

```sh
send_signal $PROBE/headers
send_signal $PROBE/get
send_signal -H "$AUTH $TOKEN" $PROBE/get
send_signal $PROBE/anything/admin
send_signal -H "$AUTH $TOKEN" $PROBE/anything/admin
send_signal -H "$AUTH $GROUPS_TOKEN" $PROBE/anything/admin
```

```text
200
403
200
403
403
200
```

The public path answers without a token, `/get` needs any token, and only the groups token reaches the admin path. If a line still shows the old answer, wait half a minute and send it again: connections that were already open keep the old rules for a while.

Now submit:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-02
```

---

## Common Mistakes

- **Adding a second policy.** A new `ALLOW` policy for `/headers` makes the path public too, but the task asks for `probe-access` as the only policy. Fix the rule in place.
- **Removing the `when` block.** Then every valid token reaches the admin path, and the demo token gets `200` instead of `403`.
- **Changing the `RequestAuthentication`.** It was correct. The grader checks that `probe-jwt` is unchanged.
- **Trusting `istioctl analyze`.** It does not know which claims your issuer puts in a token, so it does not report the wrong claim name.
