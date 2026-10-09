# Overview: Inspect Workload Identity And Certificates (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Istio and the Starfleet, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod`, no
  gateways). `istiod` is Istio's control plane: it sends configuration to
  every proxy and acts as the certificate authority (CA) that signs every
  workload's certificate.
- Mesh-wide **access logs**: every proxy writes one line per request. Read them
  with `kubectl logs -n starfleet deploy/probe-v1 -c istio-proxy`.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`. Every pod shows `2/2`: the app plus its
  `istio-proxy` sidecar proxy (Envoy), which handles all inbound and outbound
  traffic of the pod. Each workload runs under a service account, and that
  service account is part of the identity in its certificate:

  | Workload | Service account | Identity |
  | --- | --- | --- |
  | `bridge` | `starfleet-bridge` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-bridge` |
  | `cargo` | `starfleet-cargo` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-cargo` |
  | `scout` v1, v2, v3 | `starfleet-scout` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-scout` |
  | `navcom` | `starfleet-navcom` | `spiffe://cluster.local/ns/starfleet/sa/starfleet-navcom` |
  | `shuttle` (your `curl` client) | `shuttle` | `spiffe://cluster.local/ns/starfleet/sa/shuttle` |
  | `probe` v1, v2 (echo, port `8000`) | `probe` | `spiffe://cluster.local/ns/starfleet/sa/probe` |
  | `fortio` (a second caller) | `default` | `spiffe://cluster.local/ns/starfleet/sa/default` |

- Namespace **`outpost`**, with sidecar injection **off**. Its pod, the
  **`drifter`**, shows `1/1`: no sidecar proxy, so no certificate and
  no identity. It can only send plain text.
- **No `PeerAuthentication` and no `AuthorizationPolicy`.** Certificates are issued
  anyway: identity does not wait for a rule to use it.
- On your own machine you need `jq` and `openssl` to decode certificates.

## Helpers

Paste these once in each new terminal. `show_badge` prints the SAN (Subject
Alternative Name, the field that holds the identity) of the workload you name;
the second argument is the namespace and defaults to `starfleet`.
`check_callers` sends one request to the `probe` Service from `shuttle`,
`fortio` and `drifter`, and prints each status code.

```sh
show_badge() {
  istioctl proxy-config secret "$1" -n "${2:-starfleet}" -o json \
    | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
    | base64 --decode | openssl x509 -noout -ext subjectAltName
}
check_callers() {
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle: %{http_code}\n" http://probe:8000/get
  kubectl exec -n starfleet deploy/fortio -c fortio -- fortio load -quiet -n 1 http://probe:8000/get 2>&1 | grep -o 'Code [0-9]*' | sed 's/Code /fortio:  /'
  kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "drifter: %{http_code}\n" http://probe.starfleet:8000/get
}
```

Use them like this: `show_badge deploy/bridge-v1`, `check_callers`.

## Things to try

Each idea below builds on the files you made while reading the module. The
module's parts show the full YAML and the real output for each step.

- Predict the identity of every workload from the table above, then check
  three of them with `show_badge`. Pick two workloads that share an identity.
- Give `fortio` its own service account: create a ServiceAccount called
  `fortio` in `starfleet`, run
  `kubectl set serviceaccount deploy/fortio fortio -n starfleet`, and read its
  identity again. Then think about every rule that had `sa/default` written in it.
- Scale `scout-v1` to three copies and read the identity of two of them. The pod
  names differ; the identity does not.
- With the `probe` `AuthorizationPolicy` in place (only `shuttle` allowed),
  edit the principal to end in `sa/default` and run `check_callers`.
  `shuttle` and `fortio` swap results.
- Add `spiffe://` in front of the principal. Every caller gets `403`, and
  `istioctl analyze -n starfleet` stays clean.
- Compare the `default` and `ROOTCA` rows of
  `istioctl proxy-config secret deploy/shuttle -n starfleet`, then restart the
  `shuttle` Deployment and compare again. Only the `default` row changes.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-010-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-010-01`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar, so no
  certificate. Run `kubectl rollout restart deploy -n starfleet`.
- `show_badge` prints `Could not find certificate`: the pod has no proxy, or
  you forgot the namespace (`show_badge deploy/drifter outpost` has nothing to
  show, by design).

## When you're done

```sh
astrona destroy ats-015-playground-010-01
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

Two exam-style tasks for this playground. Start the playground
first, and paste the `show_badge` helper from
the Helpers section above. The solutions use it.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

### Task 1: read two identities

> In namespace `starfleet`, find the SPIFFE identity of `navcom` and of
> `scout-v3` from the certificates their proxies hold. Then write the exact
> value you would put in an `AuthorizationPolicy`'s `principals` field for
> `navcom`. Can a policy tell `scout-v3` apart from `scout-v1`?

<details><summary>Solution</summary>

Read both identities:

```sh
show_badge deploy/navcom-v1
show_badge deploy/scout-v3
```

```text
X509v3 Subject Alternative Name: critical
    URI:spiffe://cluster.local/ns/starfleet/sa/starfleet-navcom
X509v3 Subject Alternative Name: critical
    URI:spiffe://cluster.local/ns/starfleet/sa/starfleet-scout
```

The `principals` value for `navcom` is the same name without `spiffe://`:

```text
cluster.local/ns/starfleet/sa/starfleet-navcom
```

No policy can tell `scout-v3` from `scout-v1`: all three `scout` versions run
as the service account `starfleet-scout`, so they have the same identity.

</details>

### Task 2: allow only bridge to call cargo

> In namespace `starfleet`, allow only the `bridge` to call `cargo`. Match on
> the bridge's mesh identity. The bridge page must still show the cargo facts,
> and the `shuttle` must get `403` when it calls `http://cargo:9080/details/0`.

<details><summary>Solution</summary>

The bridge runs as `starfleet-bridge` (check with `show_badge deploy/bridge-v1`).

Save this as `authorizationpolicy-cargo.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cargo
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: cargo
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-bridge
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-cargo.yaml
```

Then check the result. Give the new rule up to a minute to reach every proxy:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle -> cargo: %{http_code}\n" http://cargo:9080/details/0
kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage | grep -o -m1 'paperback\|Error fetching product details'
```

```text
shuttle -> cargo: 403
paperback
```

The `cargo` proxy denies the `shuttle` request. The `bridge` page still shows
`paperback`, a fact it got from `cargo`, so the request from `bridge` was allowed.

Remove the rule when you are done:

```sh
kubectl delete authorizationpolicy cargo -n starfleet
```

</details>
