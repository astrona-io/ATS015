# Practice: Enforce mTLS With PeerAuthentication At Three Scopes

Two exam-style tasks for this playground. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solutions use them.

Try each task on your own first, then open the solution. Start each task with
no `PeerAuthentication` and no `DestinationRule` in the cluster
(`kubectl get peerauthentication,destinationrule -A` lists nothing).

## Task 1: one workload requires mTLS

> Make **only** the `navcom` workload in `starfleet` require mTLS. Every other
> workload in `starfleet` keeps accepting plain text.

<details><summary>Solution</summary>

A policy for one workload lives in that workload's namespace and has a
`selector`. Without the selector it would cover the whole namespace.

Save this as `peerauthentication-navcom-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: navcom-strict
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
  mtls:
    mode: STRICT
```

Apply it:

```bash
kubectl apply -f peerauthentication-navcom-strict.yaml
```

Then check the result:

```bash
from_drifter http://navcom.starfleet:9080/ratings/0
from_drifter $PROBE_URL
from_shuttle http://navcom.starfleet:9080/ratings/0
```

```text
drifter: 000  exit=56
drifter: 200  exit=0
shuttle: 200
```

The drifter is refused by `navcom` only. The shuttle still gets in, because
its sidecar proxy uses mTLS for it.

</details>

## Task 2: the shuttle gets 503 from a strict probe

Set up the problem first. Save this as
`peerauthentication-starfleet-strict.yaml`:

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

Save this as `destinationrule-probe-broken.yaml`:

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

Apply both:

```bash
kubectl apply -f peerauthentication-starfleet-strict.yaml -f destinationrule-probe-broken.yaml
```

> The shuttle gets `503` from the probe. Make the shuttle reach the probe over
> mTLS again. The `starfleet` namespace must stay `STRICT`.

<details><summary>Solution</summary>

`PeerAuthentication` only says what the server accepts. The `DestinationRule`
says what the caller sends, and it tells the shuttle to send plain text. Read
the shuttle's access log first:

```bash
from_shuttle $PROBE_URL
kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```text
shuttle: 503
[2026-10-09T06:52:32.147Z] "GET /get HTTP/1.1" 503 UC upstream_reset_before_response_started{connection_termination} - "-" 0 95 0 - "-" "curl/8.11.1" "a5a01e0f-dff5-44d0-b61a-72732d1659ce" "probe.starfleet:8000" "10.244.0.13:8080" outbound|8000||probe.starfleet.svc.cluster.local 10.244.0.12:48664 10.96.109.223:8000 10.244.0.12:33298 - default
```

`UC` means the server closed the connection. Fix the client side, not the
server. Save this as `destinationrule-probe.yaml`:

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

```bash
kubectl apply -f destinationrule-probe.yaml
```

Then check the result:

```bash
from_shuttle $PROBE_URL
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A1 -i client-cert
```

```text
shuttle: 200
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=5873bb3241d664a206325566eb1c1a96b2430e8dc00051146f675444d6fd9fe1;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
```

Deleting the `DestinationRule` works too: auto mTLS then picks mTLS by itself.

</details>
