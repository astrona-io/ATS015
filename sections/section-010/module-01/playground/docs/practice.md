# Practice: Inspect Workload Identity And Certificates

Two exam-style missions for this playground, astronaut. Start the playground
first, and paste the `show_badge` helper from
[overview.md](./overview.md#helpers). The solutions use it.

Try each task on your own first, then open the solution. The solutions were
run and checked on a real cluster.

## Task 1: read two badges

> In namespace `starfleet`, find the SPIFFE identity of `navcom` and of
> `scout-v3` from the certificates their proxies hold. Then write the exact
> value you would put in an `AuthorizationPolicy`'s `principals` field for
> `navcom`. Can a policy tell `scout-v3` apart from `scout-v1`?

<details><summary>Solution</summary>

Read both badges:

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

No policy can tell `scout-v3` from `scout-v1`: all three scout ship classes run
as the service account `starfleet-scout`, so they carry the same badge.

</details>

## Task 2: only the bridge may call cargo

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

Then check the result. Give the new rule up to a minute to reach every ship:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "shuttle -> cargo: %{http_code}\n" http://cargo:9080/details/0
kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage | grep -o -m1 'paperback\|Error fetching product details'
```

```text
shuttle -> cargo: 403
paperback
```

The shuttle is turned away at cargo's airlock. The bridge page still shows
`paperback`, a fact it got from cargo, so the bridge's own signal got through.

Remove the rule when you are done:

```sh
kubectl delete authorizationpolicy cargo -n starfleet
```

</details>
