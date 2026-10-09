# Overview: Authorize On JWT Claims (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is mission control: it sends every proxy its orders.
- Mesh-wide **access logs**, so every proxy writes one line per request. This
  is the ship's flight log, and you read it with
  `kubectl logs -n starfleet deploy/probe-v1 -c istio-proxy`.
- Namespace **`starfleet`** (the planet you work on), labelled
  `istio-injection=enabled`, with:
  - **The Starfleet** (the Istio docs' Bookinfo sample with space names):
    `bridge`, `cargo`, `scout` v1 to v3 and `navcom`. This module does not use
    them; they are there so the planet looks like the other playgrounds.
  - **`shuttle`**, your client pod inside the mesh. You send every test signal
    from it with the `curl` command.
  - **`probe`** v1 and v2 behind one Service on port `8000`. It echoes what
    it receives. `/headers`, `/get` and `/anything/...` all answer `200`, so
    any other status comes from the mesh, not from the probe.
- Every pod (spaceship) shows `2/2`: the app plus its `istio-proxy` sidecar,
  the communications officer that every signal in or out goes through.
- A **`RequestAuthentication`** named `probe-jwt` on the probe, for Istio's
  sample issuer `testing@secure.istio.io`. It is a precondition: tokens are
  checked, but none is required yet.
- **No `AuthorizationPolicy`.** Writing them is the point of the module.

**Outbound internet is required.** `istiod` downloads the issuer's public keys
from GitHub, and you download the sample tokens from there too.

## Helpers

Paste this once in each new terminal. It downloads Istio's two sample tokens
and defines `check_status`, which sends 3 signals from the shuttle and prints
each status code. Any `curl` options you give it are passed on.

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

Use it like this: `check_status -H "$AUTH $GROUPS_TOKEN" $PROBE/headers`.

`TOKEN` has the claim `foo: bar` and no groups. `GROUPS_TOKEN` has
`groups: [group1, group2]` and `scope: [scope1, scope2]`. Both have the same
issuer and the same subject.

## Things to try

Each idea below is a small change to a policy you made while reading the
module. Edit your saved file, apply it with `kubectl apply -f`, and watch what
happens. The module's parts show the full YAML for every step.

- Decode both tokens with `echo "$GROUPS_TOKEN" | cut -d. -f2 | base64 -d`
  and list every claim before you write a single rule.
- Require `groups` to contain `group1`. Then change the value to `group2`.
  Both work for `GROUPS_TOKEN`: a list claim matches if any item matches.
- Put `values: ["group3", "group2"]` in one `when` entry. It still matches:
  values inside one entry are combined with OR.
- Split it into two `when` entries, one for `group1` and one for `group3`.
  Now it fails: separate entries are combined with AND.
- Require `scope` to contain `scope3`. No sample token has it, so even a valid
  token gets `403`.
- Misspell the claim name (`group` instead of `groups`). Kubernetes accepts it,
  and every request is refused.
- Add a rule with only `to: paths: ["/headers"]`. That path is now public,
  while every other path still needs a token.
- Switch a claim rule to `action: DENY` and work out which tokens now get
  through.

For exam-style practice with checked solutions, see
[practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

This keeps the `probe-jwt` `RequestAuthentication` in place.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-030-02`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-030-02`.
- A pod shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.
- Every request with a token gets `401`: `istiod` could not download the
  keys. Check that the machine has internet access.

## When you're done

```sh
astrona destroy ats-015-playground-030-02
```

(`astrona destroy` takes the environment name, not the configuration path.)
