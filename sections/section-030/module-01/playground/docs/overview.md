# Overview: Authenticate End Users With JWT (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: a clean environment for practice. It
starts a fresh cluster, installs Istio and the Starfleet sample app, and then
waits. There is no task, no `astrona submit` and no pass or fail. Explore,
break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is Istio's control plane: it sends configuration and
  certificates to every proxy. In this module it also downloads the signing
  keys that tokens are checked against.
- Mesh-wide **access logs**, so every proxy writes one line per request. You
  read them with
  `kubectl logs -n starfleet deploy/probe-v1 -c istio-proxy`.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `navcom` and `scout` v1, v2 and v3. They are the rest of
    the sample app; nothing in this module protects them.
  - **`probe`** v1 and v2 behind one Service on port `8000`. This is the
    workload you protect with a token. `/headers` sends back the headers that
    reached it, so you can see whether the `Authorization` header arrived.
  - **`shuttle`**, your client pod inside the mesh. You send every test
    request from it with the `curl` command.
- Every pod shows `2/2`: the app plus its `istio-proxy` sidecar, the Envoy
  proxy that all inbound and outbound traffic of the pod passes through.
- **No `RequestAuthentication` and no `AuthorizationPolicy`.** Writing them is
  the point of the module, so every request is allowed.

The cluster needs **outbound internet**. You download the sample token from
`raw.githubusercontent.com`, and `istiod` downloads the matching keys from the
same place. Without it, every token is rejected.

## Helpers

Paste this once in each new terminal. It downloads Istio's sample token and
defines `check_status`, which sends 3 requests from the `shuttle` pod and prints
the status code of each. Any `curl` options you give it are passed on.

```sh
SAMPLES_URL=https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples
TOKEN=$(curl -s $SAMPLES_URL/demo.jwt)
AUTH="Authorization: Bearer"
PROBE=http://probe:8000
check_status() { for i in 1 2 3; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} " "$@"
done; echo; }
```

Use it like this: `check_status $PROBE/headers`, or
`check_status -H "$AUTH $TOKEN" $PROBE/headers`.

Wait about a minute after every `kubectl apply` before you test. The proxies
keep old connections open for a while, and those still follow the old rules.

## Things to try

Each idea below is a small change to the files you made while reading the
module. Edit your saved file, apply it with `kubectl apply -f`, and watch what
happens. The module's parts show the full YAML for every step.

- Decode the token's middle part
  (`echo "$TOKEN" | cut -d. -f2 | base64 -d`) and read `iss`, `sub` and `exp`
  before any rule exists.
- Apply only the `RequestAuthentication` and send a request with no token. It
  still gets `200`. This is the behaviour worth being surprised by once.
- Add a trailing slash to the `issuer` and watch every token start failing
  with `401`.
- Remove `forwardOriginalToken: true` and call `$PROBE/headers` with the
  token. The `Authorization` header no longer reaches the probe.
- Require a token with `requestPrincipals: ["*"]`, then narrow it to the exact
  `testing@secure.istio.io/testing@secure.istio.io` value.
- Apply the policy that requires a token **before** the
  `RequestAuthentication`. Even the valid token is refused, with `403`.
- Move the token to a query parameter with `fromParams`, and send it in the
  header anyway.

For exam-style practice, see [practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete requestauthentication,authorizationpolicy --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-030-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-030-01`.
- A pod shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.
- `$TOKEN` is empty: your machine cannot reach `raw.githubusercontent.com`.
- Every token gets `401`, even the valid one: check the `issuer` letter by
  letter, then check that `istiod` can reach the internet
  (`kubectl logs -n istio-system deploy/istiod | grep -i jwks`).

## When you're done

```sh
astrona destroy ats-015-playground-030-01
```

(`astrona destroy` takes the environment name, not the configuration path.)
