# Switch To STRICT For Good

Astronaut, the counting is done, the mode is written down, and the drifter has its communications officer. This part is the ten-second change that all the work before was for. It also shows the one setting that can still break a caller after the switch, and the rollback that makes the risk acceptable.

The commands below expect the drifter on `outpost` to run with a sidecar (`2/2`). If it still shows `1/1`, label `outpost` with `istio-injection=enabled` and restart the drifter first.

## The switch

The switch is one `PeerAuthentication` for the whole planet. This section applies it, proves it with real signals, and then proves it again on the proxy itself.

### Apply STRICT

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

Then check the result. Wait about a minute, so the new orders reach every open connection, then send one signal from each caller:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter: %{http_code}\n' --max-time 5 http://cargo.starfleet:9080/details/0
```

```text
shuttle: 200
drifter: 200
```

Both get `200`, because both now do the handshake. That is the whole point of moving the callers **before** the switch. Without the drifter's new sidecar, the second line would print `000`, and curl would exit with code 56 (connection reset).

Note what this change is not: not a restart, not a redeploy. `istiod` (mission control) radios the new orders to every proxy in flight within seconds, and open connections pick them up within about a minute. The break and the fix are equally fast, which is what makes a rollback real.

### Proof on the proxy

Two good signals prove that these two callers work. They do not prove which rule the `cargo` proxy is following. `istioctl x describe pod` asks mission control what applies to one pod:

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

The effective mode is `STRICT`, and it comes from the `default` policy on the `starfleet` planet. Check it every time: two good signals look the same whether `STRICT` is in force or not.

## The client side can still break you

`PeerAuthentication` sets what a **receiving** ship accepts. What a **sending** ship does is set on the sender's side. Inside the mesh, Istio picks mTLS for you ("auto mTLS"), so you rarely write it. A `DestinationRule` can change that, and that is the trap.

### Tell the shuttle to send plain signals

A `DestinationRule` is the docking instructions for one beacon. Its `tls.mode` tells every sender how to approach that beacon: `ISTIO_MUTUAL` means the mesh handshake, `DISABLE` means plain.

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

Then check the result. Wait about thirty seconds, send a signal from the shuttle, and read the shuttle's flight log a few seconds later:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
sleep 5
kubectl -n starfleet logs deploy/shuttle -c istio-proxy --tail=1
```

```text
shuttle: 503
[2026-10-09T07:18:09.595Z] "GET /details/0 HTTP/1.1" 503 UC upstream_reset_before_response_started{connection_termination} - "-" 0 95 3 - "-" "curl/8.11.1" "b8c468d6-f989-467f-b438-aca9773b3215" "cargo:9080" "10.244.0.6:9080" outbound|9080||cargo.starfleet.svc.cluster.local 10.244.0.12:49614 10.96.253.89:9080 10.244.0.12:57296 - default
```

Both ships are in the fleet, both pods are healthy, and both have valid certificates. Still the shuttle gets `503`. Its own communications officer sent the signal plain, as the `DestinationRule` told it to, and `cargo` (now `STRICT`) closed the connection. The flag **`UC`** in the shuttle's flight log means "upstream connection terminated".

This looks different from the drifter's failure. A caller with no sidecar sees a bare connection reset. A caller with a sidecar gets a `503` from its own proxy.

Measuring before the switch catches this case too. While the planet is still `PERMISSIVE`, these plain signals get through, and `cargo`'s counter shows them as `none` with a **named** source (`source_workload="shuttle"`), not `unknown`. After the switch, they never reach `cargo`'s app, so they do not show up in its counter at all.

### Remove the trap

Delete the `DestinationRule`. The shuttle goes back to auto mTLS:

```sh
kubectl delete -f destinationrule-cargo-tls-disable.yaml
```

```text
destinationrule.networking.istio.io "cargo" deleted from starfleet namespace
```

Wait about ten seconds, then send a signal from the shuttle again:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle: %{http_code}\n' http://cargo:9080/details/0
```

```text
shuttle: 200
```

In our run, a signal sent right after the delete still got `503`. The one ten seconds later got `200`.

When a switch to `STRICT` breaks exactly one caller while its neighbours work, look first for a `DestinationRule` with `tls.mode: DISABLE` on that caller's route.

### Two errors and what they mean

| What the caller sees | Usual cause |
| --- | --- |
| Connection reset: `000`, curl exit code 56 | The server is `STRICT`, and the caller has no sidecar |
| `503` with the flag `UC` in the caller's flight log | The server is `STRICT`, and a client `DestinationRule` has `tls.mode: DISABLE` |

## The rollback plan

The rollback is to apply the `PERMISSIVE` version of the same `default` policy. It restores service in seconds, for the same reason the switch breaks things in seconds. Two habits make it a real plan:

- **Have the file, not the intention.** Keep `peerauthentication-starfleet-permissive.yaml` saved, next to the `STRICT` file, before you switch.
- **Decide the trigger in advance.** "Connection resets in any caller's logs" is a rollback trigger. "It feels wrong" is not. A trigger written down beforehand stops a twenty-minute debate during an outage.

To undo the whole migration later, go in the reverse order: switch `STRICT` back to `PERMISSIVE` first, and only then remove sidecars from callers.

## The procedure, compressed

```mermaid
flowchart TB
    M["1. Measure"] --> D["2. Write down PERMISSIVE"]
    D --> I["3. Inject and restart callers"]
    I --> R["4. Measure again"]
    R -->|"no new none"| S["5. Apply STRICT"]
    R -->|"none still rising"| I
```

The five steps, with the loop that matters: you only move on to `STRICT` when no new plain signals arrive.

1. **Measure.** `connection_security_policy` on the receiving proxy, over a window longer than your slowest regular caller.
2. **Write down.** The current `PERMISSIVE` mode, as a file. It is also your rollback.
3. **Inject.** Label the namespace, then restart. The restart is the disruptive step.
4. **Measure again.** No **new** `none` signals.
5. **Switch.** Apply `STRICT`, test real signals, check the proxy, and keep the rollback file at hand.

Steps 1 and 4 are the ones people skip under time pressure, and they are the only ones that separate this from guessing.

> *The switch is a push of new orders, so it breaks in seconds and recovers in seconds. A rollback trigger written down in advance is worth more than confidence.*

## Common pitfalls

> [!WARNING]
> - **Switching without measuring.** The failures land in the callers' logs as connection resets, often in a team that does not know the mesh changed.
> - **Forgetting callers that are not apps.** Monitoring tools, health checkers, backup jobs, and anything on a planet that was never meshed.
> - **Leaving a client `DestinationRule` with `tls.mode: DISABLE`.** The server wants the handshake, the client refuses it, and every signal fails with `503 UC` even though both ships are meshed.
> - **Trusting traffic alone.** Two good signals do not show which rule applies. Check the pod with `istioctl x describe pod`.

## Your mission: Migrate A Namespace To STRICT mTLS

You can now measure, move a caller into the mesh and switch a namespace to `STRICT` without breaking anyone. Now prove it in a graded mission: a namespace with one caller still outside the mesh must end up `STRICT`, with every caller still working.

This mission uses its own small app: a `notification-service` in namespace `migrate-demo`, a `tester` client, and an `outside-client` in namespace `outside` that still sends plain signals.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-010-03
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-010-03
astrona start ats-015-playground-010-03
```
