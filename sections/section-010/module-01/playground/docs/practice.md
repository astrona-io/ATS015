# Practice: Inspect Workload Identity And Certificates

Two exam-style tasks for this playground. Start the playground
first, and paste the `show_badge` helper from
[overview.md](./overview.md#helpers). The solutions use it.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

## Task 1: read two identities

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

## Task 2: allow only bridge to call cargo

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
