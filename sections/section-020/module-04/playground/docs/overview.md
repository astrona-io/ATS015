# Overview: External Authorization With CUSTOM Policies (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Istio
and the Starfleet, and then waits. There is no task, no `astrona submit` and
no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only).
  `istiod` is Istio's control plane: it sends every proxy its configuration.
- Mesh-wide **access logs**, so every proxy writes one line per request.
- Namespace **`starfleet`**, labelled `istio-injection=enabled`, with the
  Starfleet sample app, `shuttle` (client, identity
  `cluster.local/ns/starfleet/sa/shuttle`), `fortio` (second client) and
  **`probe`** v1 and v2: an HTTP echo server on port `8000`. `/headers`,
  `/ip`, `/get` and `/status/<code>` answer.
- **`ext-authz`**, the Istio sample external authorizer. It listens for HTTP
  on port `8000` and for gRPC on port `9000`. It allows a request only if the
  check request carries the header `x-ext-authz: allow`. Its pod has no
  sidecar proxy.
- A **`PeerAuthentication` named `default` in `starfleet`, mode `STRICT`**.
- Namespace **`outpost`** without injection, with the **`drifter`**, a client
  with no sidecar proxy and no certificate.
- **No extension provider and no `AuthorizationPolicy`.** Everything inside
  `starfleet` is allowed.

## Helpers

Paste these once in each new terminal:

```sh
from_shuttle() { kubectl exec -n starfleet deploy/shuttle -c shuttle -- curl -s -o /dev/null -w "%{http_code}\n" "$@"; }
from_fortio() { kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 "$@" 2>&1 | grep -o "Code [0-9]*"; }
PROBE=http://probe:8000
```

`from_fortio` does the same from the second client and prints a line such as `Code 403`.

`from_shuttle $PROBE/headers` prints the status code of one request from the
shuttle. Extra `curl` options are passed on, for example
`from_shuttle -H "x-ext-authz: allow" $PROBE/headers`. Wait up to about a
minute after every `kubectl apply` before you trust a test.

## Things to try

- Read `examples/01-custom-policies/01-meshconfig-extension-providers.yaml`,
  add the block to the `istio` ConfigMap and apply the `CUSTOM` policy.
- Send `/headers` with no header, with `x-ext-authz: deny` and with
  `x-ext-authz: allow`. Send `/ip` as well.
- Read the authorizer log: `kubectl logs -n starfleet deploy/ext-authz`.
- Switch the policy to the gRPC provider and repeat the tests.
- Add an `ALLOW` policy on the probe that allows only the shuttle, then send a
  request from `fortio` with `x-ext-authz: allow` and read the response.
- Change the `CUSTOM` rule to `paths: ["/*"]` and see which paths ask the authorizer.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

The `extensionProviders` block stays in the `istio` ConfigMap until you remove it.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old one
  is still there: `astrona destroy ats-015-playground-020-04`, then run again.
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-020-04`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`. The `ext-authz` pod has no
  sidecar on purpose and shows `1/1`.

## When you're done

```sh
astrona destroy ats-015-playground-020-04
```

## Practice tasks

Two exam-style tasks. Paste the helpers first. Wait up to about a minute after
each apply before you trust a test.

### Task 1: send one path of the probe to the external authorizer

> Register the sample HTTP authorizer as an extension provider named
> `starfleet-authz`. Make every request to `/headers` of the `probe` ask it.
> `/ip` must not ask it.

<details><summary>Solution</summary>

Add the provider to the `mesh` key of the `istio` ConfigMap. The commands read
the current value, append the block and write it back:

```sh
mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}')
new=$(printf '%s\nextensionProviders:\n- name: starfleet-authz\n  envoyExtAuthzHttp:\n    service: ext-authz.starfleet.svc.cluster.local\n    port: "8000"\n    includeRequestHeadersInCheck: ["x-ext-authz"]\n' "$mesh")
kubectl patch configmap istio -n istio-system --type merge \
  -p "$(jq -n --arg m "$new" '{data:{mesh:$m}}')"
```

Then apply the policy:

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

`from_shuttle $PROBE/headers` returns `403`. `from_shuttle -H "x-ext-authz: allow" $PROBE/headers`
returns `200`. `from_shuttle $PROBE/ip` returns `200` with no header.

</details>

### Task 2: show that an allowed check does not skip a DENY

> With task 1 in place, add a policy so that `fortio` is refused on `/headers`
> even when it sends `x-ext-authz: allow`.

<details><summary>Solution</summary>

`CUSTOM` is checked first, then `DENY`, then `ALLOW`. A `CUSTOM` allow does not
end the decision, so a `DENY` still applies:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-fortio
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/default"]
```

After you apply it, a request from `fortio` with the header gets `403`. The
`shuttle` with the header still gets `200`.

</details>
