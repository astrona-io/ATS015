# Client And Server Must Agree

Every policy so far worked on the receiving workload. But mTLS needs both sides. If the sending sidecar is told *not* to use mTLS, a strict receiver closes the connection, even when both workloads are in the mesh and both are healthy. In this part you meet the object that controls the sending side, break a request with it on purpose, and fix it.

## Two sides, two objects

Each side of a connection has its own setting, in its own object. Mixing them up is the cause of a whole family of confusing failures.

### Who decides what

```text
   sending workload (client)                receiving workload (server)
   ─────────────────────────                ───────────────────────────
   what do I SEND?                          what do I ACCEPT?
   DestinationRule                          PeerAuthentication
   trafficPolicy.tls.mode                   mtls.mode
```

A `PeerAuthentication` sets what the receiving workload accepts. It never changes what a workload sends. A `DestinationRule` sets the traffic policy that callers use for one host (one Service), such as load balancing and TLS. Its field `trafficPolicy.tls.mode` says whether callers use mTLS.

### The client-side modes

| `tls.mode` | The calling sidecar… |
| --- | --- |
| `ISTIO_MUTUAL` | uses mTLS with its Istio certificate |
| `DISABLE` | sends plain text |
| `SIMPLE` | starts plain TLS (only the server shows a certificate), for services outside the mesh |
| `MUTUAL` | does mTLS with certificates you provide yourself, for services outside the mesh |

### Auto mTLS fills the gap

Normally you set none of this. **Auto mTLS** makes the calling sidecar choose by itself: if the receiving workload has a sidecar and accepts mTLS, it uses mTLS; if the receiver's policy says `DISABLE`, it sends plain text. Auto mTLS only steps in when no `DestinationRule` sets `tls.mode` for that host. Once you set it, your setting wins, right or wrong.

## Break mTLS on purpose

Now see the mismatch once, deliberately: a strict probe, and a `DestinationRule` that tells callers to send plain text.

<!-- astrona:playground:renew -->

### Make the namespace strict, then misconfigure the caller

The commands below need the `starfleet` namespace policy with `mode: STRICT` applied. Apply the file you saved for it:

```sh
kubectl apply -f peerauthentication-starfleet-strict.yaml
```

Save this as `destinationrule-probe-tls-disable.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe
  namespace: starfleet
spec:
  host: probe
  trafficPolicy:
    tls:
      mode: DISABLE
```

Apply it:

```sh
kubectl apply -f destinationrule-probe-tls-disable.yaml
```

### Read the failure

Send a request from the shuttle, then read the last line of the shuttle's access log:

```sh
from_shuttle $PROBE_URL
kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```text
shuttle: 503
[2026-10-09T06:51:19.920Z] "GET /get HTTP/1.1" 503 UC upstream_reset_before_response_started{connection_termination} - "-" 0 95 1 - "-" "curl/8.11.1" "3c1996a7-9f07-4092-baa0-88aff5ce277a" "probe.starfleet:8000" "10.244.0.13:8080" outbound|8000||probe.starfleet.svc.cluster.local 10.244.0.12:54390 10.96.109.223:8000 10.244.0.12:49984 - default
```

The sidecar writes its access log in small batches. If the last line is still an older `200`, wait a few seconds and read the log again.

This time there *is* a status code: `503`. The shuttle's own sidecar proxy wrote it, because it reached the probe and the probe closed the connection. The access log flag **`UC`** means "upstream connection termination": the receiving side closed the connection before it answered.

Compare the two failures. The drifter has no sidecar, so nobody on its side can write a status; it gets `000`. The shuttle has a sidecar that saw the connection drop, so it gets `503 UC`.

## Fix the sending side

The probe is right to be strict. The fault is in the `DestinationRule`, so fix that and leave the server alone.

### Say ISTIO_MUTUAL

Save this as `destinationrule-probe.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe
  namespace: starfleet
spec:
  host: probe
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

Apply it:

```sh
kubectl apply -f destinationrule-probe.yaml
```

Then check that the shuttle's identity arrives again:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A2 -i client-cert
```

```text
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=5873bb3241d664a206325566eb1c1a96b2430e8dc00051146f675444d6fd9fe1;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
    ],
```

The probe received the shuttle's identity, so the request used mTLS. `ISTIO_MUTUAL` gives the same result as auto mTLS. You need it when a `DestinationRule` already has a `trafficPolicy` for another reason (for example load balancing) and you want mTLS written down, or when auto mTLS is switched off. Deleting the `DestinationRule` would also have fixed the problem.

## A receiver that refuses mTLS

The last mode works the other way round: the receiver will not use mTLS at all. Watch what auto mTLS does with it.

### Set the probe to DISABLE

Remove the `DestinationRule`, so auto mTLS decides again. An explicit `ISTIO_MUTUAL` would keep starting a TLS handshake with a server that refuses it. We tried it: the shuttle then gets `503` with the flag `UF` and a TLS error in its access log.

```sh
kubectl delete -f destinationrule-probe.yaml
```

Save this as `peerauthentication-probe-disable.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  mtls:
    mode: DISABLE
```

Apply it:

```sh
kubectl apply -f peerauthentication-probe-disable.yaml
```

Then call the probe from both clients, and count the identity headers:

```sh
from_shuttle $PROBE_URL
from_drifter $PROBE_URL
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -c -i client-cert
```

```text
shuttle: 200
drifter: 200  exit=0
0
```

Nothing broke. Auto mTLS read the probe's policy and made the shuttle send plain text. But look at the last number: `0`. Even the shuttle's request now arrives without an identity and without encryption. Any rule that checks "is this the shuttle?" has nothing left to check. Use `DISABLE` only for a workload that truly cannot use mTLS.

### Clean up

Remove both policies, so the namespace is back to the default:

```sh
kubectl delete -f peerauthentication-probe-disable.yaml -f peerauthentication-starfleet-strict.yaml
```

## Common pitfalls

> [!WARNING]
> - **A `DestinationRule` with `tls.mode: DISABLE` against a `STRICT` server.** Every call from the mesh fails with `503 UC`, with both workloads meshed and healthy. Look for it first when exactly one caller breaks after a rollout.
> - **Copying a `trafficPolicy` from another service.** A copied `tls` block turns auto mTLS off for that host. Check every `DestinationRule` for a `tls` field you did not mean to write.
> - **Loosening the server to fix a client problem.** Setting the receiver to `PERMISSIVE` or `DISABLE` hides a `503 UC`, and removes the protection you wanted. Fix the `DestinationRule` instead.
> - **Tightening the server before the callers are ready.** Make every caller able to do mTLS first, then switch the server to `STRICT`.

> *`PeerAuthentication` says what a workload accepts; the `DestinationRule` says what callers send. When they disagree, the caller's sidecar reports `503 UC`.*

## Your mission: Fix A DestinationRule That Breaks mTLS

You can now tell a client-side mTLS problem from a server-side one, and fix it on the right side. Now prove it in a graded lab: the shuttle gets `503` from a strict probe, and you must make it work again without weakening the namespace policy.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-010-02
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-03
```

Read the task in [`question.md`](./labs/lab-03/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-03
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-010-02-03
astrona start ats-015-playground-010-02
```
