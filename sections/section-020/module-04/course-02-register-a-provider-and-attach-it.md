# Register A Provider And Attach It

A `CUSTOM` policy names a provider but does not describe it. The description lives in the mesh configuration, so a working setup always has two objects: an entry in `meshConfig.extensionProviders` and an `AuthorizationPolicy` that refers to it by name. This chapter writes both, then sends requests with and without the header that the sample authorizer wants.

<!-- astrona:playground:renew -->

## Register the provider

Istiod reads the mesh configuration from the ConfigMap `istio` in `istio-system`. The key `mesh` holds a YAML document. An extension provider is one item in its `extensionProviders` list. These are the two types for the sample authorizer, shown as the block you add to that document:

```yaml
extensionProviders:
- name: sample-ext-authz-http
  envoyExtAuthzHttp:
    service: ext-authz.starfleet.svc.cluster.local
    port: "8000"
    includeRequestHeadersInCheck: ["x-ext-authz"]
- name: sample-ext-authz-grpc
  envoyExtAuthzGrpc:
    service: ext-authz.starfleet.svc.cluster.local
    port: "9000"
```

The `name` is what a policy uses. The `service` is the fully qualified host name of the authorizer Service, and `port` is a string. The HTTP type needs `includeRequestHeadersInCheck` for every header the authorizer reads. Both types accept more fields, for example `timeout`, `failOpen` and `statusOnError`, and the HTTP type also accepts `pathPrefix`, `headersToUpstreamOnAllow`, `headersToDownstreamOnDeny` and `includeRequestBodyInCheck`. The defaults are `failOpen: false` and `timeout: 600s`.

Read the current value before you change it:

```sh
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}'
```

The Helm install has put its own settings in this document, such as the access log configuration. A patch that replaces the key would delete them. Append the block to the existing text and write the whole value back:

```sh
mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}')
new=$(printf '%s\nextensionProviders:\n- name: sample-ext-authz-http\n  envoyExtAuthzHttp:\n    service: ext-authz.starfleet.svc.cluster.local\n    port: "8000"\n    includeRequestHeadersInCheck: ["x-ext-authz"]\n- name: sample-ext-authz-grpc\n  envoyExtAuthzGrpc:\n    service: ext-authz.starfleet.svc.cluster.local\n    port: "9000"\n' "$mesh")
kubectl patch configmap istio -n istio-system --type merge \
  -p "$(jq -n --arg m "$new" '{data:{mesh:$m}}')"
```

`jq` builds the JSON patch so that quotes and newlines in the text are escaped correctly. If `meshConfig.extensionProviders` already existed, this would write a second `extensionProviders` key, so check the output of the first command before you append.

With a Helm installation, the durable place for this block is the `meshConfig:` value of the `istiod` chart. A later `helm upgrade` without it overwrites the ConfigMap. This module patches the ConfigMap directly because it is the fastest way to see the effect.

## Attach it to one path

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
    name: sample-ext-authz-http
  rules:
  - to:
    - operation:
        paths: ["/headers"]
```

`action: CUSTOM` and `provider.name` are the two fields that are new. The `rules` choose which requests are sent to the authorizer. Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-custom.yaml
```

## Test the three cases

Wait up to about a minute for the configuration to reach the proxies, then send three requests for the protected path and one for another path:

```sh
from_shuttle $PROBE/headers
from_shuttle -H "x-ext-authz: deny" $PROBE/headers
from_shuttle -H "x-ext-authz: allow" $PROBE/headers
from_shuttle $PROBE/ip
```

The first two print `403`: the check request has no `x-ext-authz: allow`, so the authorizer denies. The third prints `200`. The fourth prints `200` too, because `/ip` matches no rule and is never sent to the authorizer.

Read the body of a denial to see who made the decision:

```sh
kubectl exec -n starfleet deploy/shuttle -c shuttle -- curl -s $PROBE/headers
```

The sample authorizer answers with the text `denied by ext_authz for not found header` followed by the header it wanted. A response from the workload itself would be JSON. An allowed response also carries the header `X-Ext-Authz-Check-Result: allowed`, which you can see with `curl -i`.

## Switch to the gRPC provider

Change `provider.name` in the policy to `sample-ext-authz-grpc` and apply it again. The same three requests give the same results, because the sample authorizer applies the same rule on both ports. The difference is only the protocol between the proxy and the authorizer. The gRPC provider has no `includeRequestHeadersInCheck` field in the sample above: the gRPC check carries the request attributes in one message.

## Common pitfalls

> [!WARNING]
> - **Replacing the `mesh` key.** A patch that sets `data.mesh` to only the new block deletes the settings that were there. Read first, append, write back.
> - **A provider name that does not match.** The `provider.name` in the policy must equal the `name` in the mesh configuration exactly.
> - **Testing too early.** A request sent before the configuration has reached the proxy is treated under the old rules.
> - **`port` as a number.** The provider ports are strings.
