# Solution Walkthrough

The probe was right to be strict. The copied `DestinationRule` told every caller to send plain text, so the probe closed their connections. The fix belongs on the sending side.

---

## Step 1: Confirm the failure

Send one request from the shuttle, then read the shuttle's access log:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://probe:8000/get
kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```text
503
[2026-10-09T07:07:30.796Z] "GET /get HTTP/1.1" 503 UC upstream_reset_before_response_started{connection_termination} - "-" 0 95 1 - "-" "curl/8.11.1" "d7ee24f7-94fb-4b53-adf2-8e2860428ce9" "probe:8000" "10.244.0.13:8080" outbound|8000||probe.starfleet.svc.cluster.local 10.244.0.12:57898 10.96.88.64:8000 10.244.0.12:46082 - default
```

The sidecar writes its access log in small batches. If the last line is not the `503` yet, wait a few seconds and read the log again.

The flag is **`UC`**, "upstream connection termination": the shuttle's sidecar reached the probe, and the probe closed the connection before it answered. A meshed caller that gets `503 UC` from a `STRICT` server is the classic sign that the two sides disagree about mTLS.

## Step 2: Find the cause

The server side says what it accepts. Check it:

```sh
kubectl get peerauthentication -A
```

```text
NAMESPACE   NAME      MODE     AGE
starfleet   default   STRICT   5s
```

`STRICT`, as the task says. Now check what the callers are told to send:

```sh
kubectl get destinationrule probe -n starfleet -o yaml | grep -A4 "^  trafficPolicy"
```

```text
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST
    tls:
      mode: DISABLE
```

There it is: `tls.mode: DISABLE`. It came along with the copied load-balancing setting. Because the `DestinationRule` sets `tls.mode`, auto mTLS no longer decides for the probe, and every caller sends plain text.

## Step 3: Fix the DestinationRule

Keep the load balancing, and tell callers to use Istio's mTLS. Save this as `destinationrule-probe.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe
  namespace: starfleet
spec:
  host: probe
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST
    tls:
      mode: ISTIO_MUTUAL
```

Apply it:

```sh
kubectl apply -f destinationrule-probe.yaml
```

```text
destinationrule.networking.istio.io/probe configured
```

Removing the `tls` block completely works too: auto mTLS then picks mTLS by itself.

## Step 4: Prove it works

The shuttle gets an answer, and its identity arrives at the probe:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://probe:8000/get
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A2 -i client-cert
```

```text
200
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=c0ee977c4eea8dd88255e573c4dc54183f56182ad8a7cc1f30da5652ef9653e5;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
    ],
```

A changed `DestinationRule` can take up to a minute to reach the shuttle's sidecar. If you still get `503`, wait and try again.

The drifter, with no sidecar, is still refused:

```sh
kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://probe.starfleet:8000/get
```

```text
000
command terminated with exit code 56
```

Now submit:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-03
```

---

## Common Mistakes

- **Loosening the server.** A `PERMISSIVE` or `DISABLE` policy for the probe makes the `503` go away, but the shuttle's request then travels without its identity. The grader checks that the server side is unchanged.
- **Deleting the `DestinationRule`.** mTLS works again, but the team loses its `LEAST_REQUEST` load balancing. The task asks you to keep it.
- **Setting `tls.mode: MUTUAL` or `SIMPLE`.** Those are for services outside the mesh, with certificates you provide yourself. Inside the mesh, use `ISTIO_MUTUAL`.
- **Testing too fast.** `kubectl apply` returns before the shuttle's sidecar has the new configuration. If you still get `503`, wait up to a minute and try again.
