# Solution Walkthrough

Mission debrief, astronaut. The drifter calls the probe on port `8000`, but that is only the Service's call sign. The probe pods listen on `8080`, and the sidecar enforces the mode on the port the pod listens on. So the exception goes on `8080`.

---

## Step 1: Confirm the starting point

Check the policies, then send the drifter's signal to the probe:

```sh
kubectl get peerauthentication -A
kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://probe.starfleet:8000/get
```

```text
NAMESPACE      NAME      MODE     AGE
istio-system   default   STRICT   1s
000
command terminated with exit code 56
```

The mesh-wide policy is in force, and the drifter's connection is reset: `000`, no HTTP answer.

## Step 2: Find the port the pod listens on

`portLevelMtls` takes the container port. Read it off the Service:

```sh
kubectl get service probe -n starfleet -o jsonpath='{.spec.ports[0].port} -> {.spec.ports[0].targetPort}{"\n"}'
```

```text
8000 -> 8080
```

Callers dial `8000`. The pod listens on `8080`. The key is `8080`.

## Step 3: Open one port

Save this as `peerauthentication-probe.yaml`:

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
    mode: STRICT
  portLevelMtls:
    8080:
      mode: PERMISSIVE
```

Apply it:

```sh
kubectl apply -f peerauthentication-probe.yaml
```

```text
peerauthentication.security.istio.io/probe created
```

The `selector` makes this a workload policy, which `portLevelMtls` needs. `mode: STRICT` keeps every other port of the probe strict.

## Step 4: Prove it works

The drifter reaches the probe, and is still refused by the scout and navcom:

```sh
for url in http://probe.starfleet:8000/get http://scout.starfleet:9080/reviews/0 http://navcom.starfleet:9080/ratings/0; do
  kubectl exec -n outpost deploy/drifter -- curl -s -o /dev/null -w "$url %{http_code}\n" --max-time 5 $url 2>/dev/null
done
```

```text
http://probe.starfleet:8000/get 200
http://scout.starfleet:9080/reviews/0 000
http://navcom.starfleet:9080/ratings/0 000
```

A new policy can take up to a minute to reach every proxy. If the probe still answers `000`, wait and run the loop again.

The shuttle still uses the handshake. Its identity arrives at the probe:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://probe:8000/headers | grep -A2 -i client-cert
```

```text
    "X-Forwarded-Client-Cert": [
      "By=spiffe://cluster.local/ns/starfleet/sa/probe;Hash=6a804878dc2c41706a23b6d67f39c5f7768996d3f08b8f8744ee2c9a8d3b27b2;Subject=\"\";URI=spiffe://cluster.local/ns/starfleet/sa/shuttle"
    ],
```

Now submit:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-02
```

---

## Common Mistakes

- **Using `8000` as the key.** It is the Service port. The policy is accepted and does nothing, and the drifter is still refused.
- **Leaving out the `selector`.** `portLevelMtls` only works in a workload policy. `kubectl apply` refuses it with `portLevelMtls requires selector`.
- **Setting the whole probe to `PERMISSIVE`.** The drifter gets in, but so would plain text on every other port. The grader checks that only `8080` is open.
- **A namespace-wide `PERMISSIVE` policy in `starfleet`.** It opens every ship on the planet, and the drifter reaches the scout too.
- **Testing too fast.** `kubectl apply` returns before the probe's sidecar has the new orders. If the drifter still gets `000`, wait up to a minute and try again.
