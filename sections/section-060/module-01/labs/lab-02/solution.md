# Solution Walkthrough

Mission debrief, astronaut. Both rules are about **who** is calling, and nothing else. ztunnel reads the caller's identity from the certificate on the HBONE tunnel, so it can enforce both rules with no waypoint. A label `selector` points each rule at the right pods.

---

## Step 1: Check the starting point

Confirm that every ship is in the mesh through ztunnel, and that no waypoint exists:

```sh
istioctl ztunnel-config workload | grep -E "NAMESPACE|starfleet"
kubectl get gateway -n starfleet
```

```text
NAMESPACE          POD NAME                                                          ADDRESS     NODE                                      WAYPOINT PROTOCOL
starfleet          bridge-v1-bc4dc4fcc-jr82s                                         10.244.0.13 astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          cargo-v1-6f787f8bd5-hfdtj                                         10.244.0.8  astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          navcom-v1-7467bbc689-bj5jz                                        10.244.0.9  astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          scout-v1-85bf65868-zcpn4                                          10.244.0.10 astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          scout-v2-866c98b568-7p64w                                         10.244.0.11 astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          scout-v3-668c6dfc68-78pnl                                         10.244.0.12 astro-ats-015-lab-060-01-02-control-plane None     HBONE
starfleet          shuttle-7b5db664c-v7b6x                                           10.244.0.14 astro-ats-015-lab-060-01-02-control-plane None     HBONE
No resources found in starfleet namespace.
```

`PROTOCOL: HBONE` means ztunnel carries each ship's traffic and knows its identity. No waypoint means only L4 rules can work, which is exactly what the task asks for.

Find the service accounts, because the rules name them:

```sh
kubectl get deploy -n starfleet -o custom-columns='NAME:.metadata.name,SERVICE ACCOUNT:.spec.template.spec.serviceAccountName'
```

```text
NAME        SERVICE ACCOUNT
bridge-v1   starfleet-bridge
cargo-v1    starfleet-cargo
navcom-v1   starfleet-navcom
scout-v1    starfleet-scout
scout-v2    starfleet-scout
scout-v3    starfleet-scout
shuttle     shuttle
```

## Step 2: Lock the supply ship to the flagship

The identity of a workload is `cluster.local/ns/<namespace>/sa/<service-account>`, written without `spiffe://`.

Save this as `authorizationpolicy-cargo-l4.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cargo-l4
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
kubectl apply -f authorizationpolicy-cargo-l4.yaml
```

Wait about a minute: a new rule takes that long to reach live traffic, because open connections keep the old rule. Then check the result, first from the shuttle and then through the bridge:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://cargo:9080/details/0
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://bridge:9080/api/v1/products/0
```

```text
000
command terminated with exit code 56
200
```

The shuttle gets `000`: ztunnel closed the connection, because the shuttle's identity is not `starfleet-bridge`. There is no `403`, because ztunnel does not speak HTTP. The bridge still gets `200`, because it signals `cargo` with its own identity.

## Step 3: Lock the navigation computer to the scouts

All three scout versions run as the same service account, `starfleet-scout`, so one principal covers them all.

Save this as `authorizationpolicy-navcom-l4.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-l4
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-scout
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-l4.yaml
```

Wait about a minute again, then check the result. The shuttle should be refused, and the scouts should still get their ratings:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://navcom:9080/ratings/0
for i in 1 2 3 4 5 6; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s http://scout:9080/reviews/0 | grep -o '"stars": *[0-9]*\|Ratings service is currently unavailable' | head -1
done
```

```text
000
command terminated with exit code 56
"stars": 5
"stars": 5
"stars": 5
```

The shuttle gets `000`. The v2 and v3 scouts still show stars, because they signal `navcom` as `starfleet-scout`. The v1 scout never asks for ratings, so its answers print nothing: that is why six signals gave three star lines here. Your count can differ, because the scout beacon picks a ship class at random.

## Step 4: Ask ztunnel what it enforces

List the policies ztunnel holds, and read its log for the refused connections:

```sh
istioctl ztunnel-config policy
kubectl logs -n istio-system ds/ztunnel --tail=20 | grep -i "policy"
```

```text
NAMESPACE POLICY NAME ACTION SCOPE
starfleet cargo-l4    Allow  WorkloadSelector
starfleet navcom-l4   Allow  WorkloadSelector
2026-10-09T11:55:01.094336Z	error	access	connection complete	src.addr=10.244.0.14:46992 src.workload="shuttle-7b5db664c-v7b6x" src.namespace="starfleet" src.identity="spiffe://cluster.local/ns/starfleet/sa/shuttle" dst.addr=10.244.0.9:15008 dst.hbone_addr=10.244.0.9:9080 dst.service="navcom.starfleet.svc.cluster.local" dst.workload="navcom-v1-7467bbc689-bj5jz" dst.namespace="starfleet" dst.identity="spiffe://cluster.local/ns/starfleet/sa/starfleet-navcom" direction="inbound" bytes_sent=0 bytes_recv=0 duration="0ms" error="connection closed due to policy rejection: allow policies exist, but none allowed"
```

Both rules sit in ztunnel. The log line is the shuttle's refused connection to `navcom`: `src.identity` names the caller, and "allow policies exist, but none allowed" is the reason. No waypoint was needed.

## Step 5: Submit

```sh
astrona submit -c sections/section-060/module-01/labs/lab-02
```

## If it does not pass

- **The bridge's API no longer gives `200`.** The `cargo-l4` principal is wrong. Check the spelling of `starfleet-bridge`, and leave out `spiffe://`.
- **A scout answer says "Ratings service is currently unavailable".** The `navcom-l4` principal is wrong, or it names a scout version instead of the service account.
- **The bridge and the scouts are locked out too.** One of the rules contains a method or a path. ztunnel cannot read those, so it fails safe and the `ALLOW` matches nobody. Keep the rules to identity only.
- **The shuttle still reaches `cargo`.** The `selector` does not match the pods: it must be `app: cargo`.
