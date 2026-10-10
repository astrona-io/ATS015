# Switch The Namespace To STRICT mTLS

All the work so far leads to one change of about ten seconds. The plain-text requests are counted, the mode is written down, and the `drifter` pod has its sidecar proxy. This chapter makes the switch, shows the one setting that can still break a client after it, and plans the rollback that makes the risk acceptable.

The commands below expect the `drifter` pod in `outpost` to run with a sidecar (`2/2`). If it still shows `1/1`, label `outpost` with `istio-injection=enabled` and restart `drifter` first.

## The switch

The switch is one `PeerAuthentication` for the whole namespace. A `PeerAuthentication` sets whether a workload accepts plain text, mTLS (mutual TLS, where both sides present a certificate) or both on inbound connections. You apply it, prove it with real requests, and then prove it again on the proxy itself.

<!-- astrona:playground:renew -->

Save this as `peerauthentication-starfleet-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-starfleet-strict.yaml
```

Then check the result. Wait about a minute, so the new configuration reaches every open connection, then send one request from each client:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter: %{http_code}\n' --max-time 5 http://cargo.starfleet:9080/details/0
```

```text
shuttle: 200
drifter: 200
```

Both clients get `200`, because both now use mTLS. That is the whole point of moving the clients **before** the switch. Without the new sidecar in the `drifter` pod, the second line would print `000`, and curl would exit with code 56 (connection reset).

Note what this change is not: not a restart, and not a redeploy. `istiod`, Istio's control plane, pushes the new configuration to every running proxy over xDS within seconds, and open connections pick it up within about a minute. The break and the fix are equally fast, and that is what makes a rollback real.

Two successful requests prove that these two clients work. They do not prove which policy the `cargo` proxy is following. For that, `istioctl x describe pod` asks `istiod` which configuration applies to one pod:

```sh
CARGO_POD=$(kubectl -n starfleet get pod -l app=cargo -o jsonpath='{.items[0].metadata.name}')
istioctl x describe pod "$CARGO_POD" -n starfleet
```

```text
Pod: cargo-v1-6f787f8bd5-9nqwb
   Pod Revision: default
   Pod Ports: 9080 (cargo)
--------------------
Service: cargo
   Port: http 9080/HTTP targets pod port 9080
--------------------
Effective PeerAuthentication:
   Workload mTLS mode: STRICT
Applied PeerAuthentication:
   default.starfleet
Skipping Gateway information (no ingress gateway pods)
```

The effective mode is `STRICT`, and it comes from the `default` policy in the `starfleet` namespace. Check it every time, because two successful requests look the same whether `STRICT` is in force or not.

## The client side can still break you

`PeerAuthentication` sets what a **receiving** proxy accepts. What a **sending** proxy does is set on the client side. Inside the mesh, Istio picks mTLS for you ("auto mTLS"), so you rarely write it. A `DestinationRule` can change that, and that is the trap.

A `DestinationRule` sets the traffic policy that client proxies use for one Service host, for example load balancing and TLS. Its `tls.mode` tells every client proxy how to connect to that host: `ISTIO_MUTUAL` means Istio's mTLS, and `DISABLE` means plain text. To see the trap, tell `shuttle` to send plain text to `cargo`.

Save this as `destinationrule-cargo-tls-disable.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: cargo
  namespace: starfleet
spec:
  host: cargo
  trafficPolicy:
    tls:
      mode: DISABLE
```

Apply it:

```sh
kubectl apply -f destinationrule-cargo-tls-disable.yaml
```

Then check the result. Wait about thirty seconds, send a request from `shuttle`, and read the access log of the `shuttle` proxy a few seconds later:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
sleep 5
kubectl -n starfleet logs deploy/shuttle -c istio-proxy --tail=1
```

```text
shuttle: 503
[2026-10-09T07:18:09.595Z] "GET /details/0 HTTP/1.1" 503 UC upstream_reset_before_response_started{connection_termination} - "-" 0 95 3 - "-" "curl/8.11.1" "b8c468d6-f989-467f-b438-aca9773b3215" "cargo:9080" "10.244.0.6:9080" outbound|9080||cargo.starfleet.svc.cluster.local 10.244.0.12:49614 10.96.253.89:9080 10.244.0.12:57296 - default
```

Both workloads are in the mesh, both pods are healthy, and both have valid certificates. Still `shuttle` gets `503`. Its own sidecar proxy sent the request as plain text, as the `DestinationRule` told it to, and the `cargo` proxy (now `STRICT`) closed the connection. The response flag **`UC`** in the `shuttle` access log means "upstream connection terminated".

This looks different from the `drifter` failure. A client with no sidecar sees a bare connection reset, while a client with a sidecar gets a `503` from its own proxy. Measuring before the switch catches this case too. While the namespace is still `PERMISSIVE`, these plain-text requests get through, and the `cargo` counter shows them as `none` with a **named** source (`source_workload="shuttle"`), not `unknown`. After the switch, they never reach the `cargo` app, so they do not show up in its counter at all.

To remove the trap, delete the `DestinationRule`. The `shuttle` proxy then goes back to auto mTLS:

```sh
kubectl delete -f destinationrule-cargo-tls-disable.yaml
```

```text
destinationrule.networking.istio.io "cargo" deleted from starfleet namespace
```

Wait about ten seconds, then send a request from `shuttle` again:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
```

```text
shuttle: 200
```

In our run, a request sent right after the delete still got `503`, and the one ten seconds later got `200`.

> [!TIP]
> When a switch to `STRICT` breaks exactly one client while the others work, look first for a `DestinationRule` with `tls.mode: DISABLE` on that client's route.

You have now seen both errors a `STRICT` server causes, and they point to different fixes:

| What the client sees | Usual cause |
| --- | --- |
| Connection reset: `000`, curl exit code 56 | The server is `STRICT`, and the client has no sidecar |
| `503` with the flag `UC` in the client's access log | The server is `STRICT`, and a client `DestinationRule` has `tls.mode: DISABLE` |

## The rollback plan

Both errors can still appear in a real cluster, from a client you did not know about. The rollback is to apply the `PERMISSIVE` version of the same `default` policy. It restores service in seconds, for the same reason the switch breaks things in seconds.

Two habits turn that into a real plan. First, have the file, not the intention: keep `peerauthentication-starfleet-permissive.yaml` saved, next to the `STRICT` file, before you switch. Second, decide the trigger in advance. "Connection resets in any client's logs" is a rollback trigger; "it feels wrong" is not. A trigger written down beforehand stops a twenty-minute debate during an outage.

To undo the whole migration later, go in the reverse order. Switch `STRICT` back to `PERMISSIVE` first, and only then remove sidecars from clients.

## The whole procedure

The migration you just finished follows five steps, with one loop in the middle:

```mermaid
flowchart TB
    M["1. Measure"] --> D["2. Write down PERMISSIVE"]
    D --> I["3. Inject and restart callers"]
    I --> R["4. Measure again"]
    R -->|"no new none"| S["5. Apply STRICT"]
    R -->|"none still rising"| I
```

The diagram shows that you only move on to `STRICT` when no new plain-text requests arrive. Each step has one job:

1. **Measure.** `connection_security_policy` on the receiving proxy, over a window longer than your slowest regular client.
2. **Write down.** The current `PERMISSIVE` mode, as a file. It is also your rollback.
3. **Inject.** Label the namespace, then restart. The restart is the disruptive step.
4. **Measure again.** No **new** `none` requests.
5. **Switch.** Apply `STRICT`, test real requests, check the proxy, and keep the rollback file at hand.

Steps 1 and 4 are the ones people skip under time pressure, and they are the only ones that separate this from guessing.

The namespace now runs `STRICT`, every client still works, and `istioctl x describe pod` confirms the mode on the proxy. You know the two errors a `STRICT` server causes and how to tell them apart. Because `istiod` pushes the switch as new configuration, it breaks in seconds and recovers in seconds. That makes a rollback trigger written down in advance worth more than confidence.

## Common pitfalls

> [!WARNING]
> - **Switching without measuring.** The failures land in the clients' logs as connection resets, often in a team that does not know the mesh changed.
> - **Forgetting clients that are not apps.** Monitoring tools, health checkers, backup jobs, and anything in a namespace that was never added to the mesh.
> - **Leaving a client `DestinationRule` with `tls.mode: DISABLE`.** The server requires mTLS, the client proxy sends plain text, and every request fails with `503 UC` even though both workloads have sidecars.
> - **Trusting traffic alone.** Two successful requests do not show which policy applies. Check the pod with `istioctl x describe pod`.
