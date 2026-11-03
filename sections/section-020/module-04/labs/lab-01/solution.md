# Solution Walkthrough

Status: **UNTESTED.** The steps follow the Istio documentation and were never run on a cluster, so this walkthrough shows no command output. Compare your results with the descriptions in each step.

You need two objects: an entry in the mesh configuration that describes the authorizer, and a `CUSTOM` policy that names it and selects one path.

---

## Step 1: Paste a test helper

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -c shuttle -- curl -s -o /dev/null -w "%{http_code}\n" "$@"; }
PROBE=http://probe:8000
```

Before any change, all requests print `200`:

```sh
from_shuttle $PROBE/headers
from_shuttle $PROBE/ip
```

## Step 2: Read the mesh configuration

```sh
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}'
```

This is a YAML document with the settings that the Istio installation wrote. It has no `extensionProviders` key yet. If it had one, you would add an item to that list and not write a second key.

## Step 3: Register the provider

Append the provider to the text and write the whole value back, so the existing settings stay:

```sh
mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}')
new=$(printf '%s\nextensionProviders:\n- name: starfleet-authz\n  envoyExtAuthzHttp:\n    service: ext-authz.starfleet.svc.cluster.local\n    port: "8000"\n    includeRequestHeadersInCheck: ["x-ext-authz"]\n' "$mesh")
kubectl patch configmap istio -n istio-system --type merge \
  -p "$(jq -n --arg m "$new" '{data:{mesh:$m}}')"
```

The `port` is a string. `includeRequestHeadersInCheck` makes the proxy send `x-ext-authz` to the authorizer. Without it the authorizer never sees the header and denies every request.

## Step 4: The CUSTOM policy

Save this as `authorizationpolicy-probe-custom.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-ext-authz
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: CUSTOM
  provider:
    name: starfleet-authz
  rules:
    - to:
        - operation:
            paths: ["/headers"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-custom.yaml
```

## Step 5: Prove all four results

Wait up to about a minute, then send the four requests from the question:

```sh
from_shuttle $PROBE/headers
from_shuttle -H "x-ext-authz: deny" $PROBE/headers
from_shuttle -H "x-ext-authz: allow" $PROBE/headers
from_shuttle $PROBE/ip
```

Expected: `403`, `403`, `200`, `200`. The first two requests match the rule and the authorizer denies them. The third carries the allowing header. The fourth path matches no rule, so it is never sent to the authorizer.

If the third request prints `403`, check that `includeRequestHeadersInCheck` is in the provider and that the provider name in the policy equals the name in the mesh configuration. If every request prints `200`, the configuration may not have reached the proxy yet, so wait and test again. The authorizer log shows which requests it received:

```sh
kubectl logs -n starfleet deploy/ext-authz
```

## Submit

```sh
astrona submit -c sections/section-020/module-04/labs/lab-01
```
