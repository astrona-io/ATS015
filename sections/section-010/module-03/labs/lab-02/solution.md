# Solution Walkthrough

Mission debrief, astronaut. The port exception named the right ship and the right mode, but the wrong port. It used the Service port `8000`. The probe's proxy only catches signals on the container port `8080`, so the exception attached to nothing and the probe stayed `STRICT`.

---

## Step 1: Confirm the failure

Send one plain signal from the drifter to the probe:

```sh
kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter: %{http_code}\n' --max-time 5 http://probe.starfleet:8000/get
```

<!-- OUTPUT PENDING: drifter: 000, then "command terminated with exit code 56" -->

`000` with exit code 56 is a connection reset. The probe's proxy closed the connection because the signal came without the mTLS handshake. That is a `STRICT` refusal, not an HTTP error.

## Step 2: Find the cause

Read the probe's policy and the probe's Service side by side:

```sh
kubectl -n starfleet get peerauthentication probe -o yaml
kubectl -n starfleet get service probe -o jsonpath='{.spec.ports[0].port} -> {.spec.ports[0].targetPort}{"\n"}'
```

<!-- OUTPUT PENDING: the PeerAuthentication spec with selector app: probe, mtls.mode STRICT and portLevelMtls "8000": PERMISSIVE; then "8000 -> 8080" -->

The exception names port `8000`. The Service listens on `8000` but passes signals on to `8080`, the container port. The proxy sits in the pod and only sees `8080`. A `portLevelMtls` key that the proxy never sees is accepted, stored, and does nothing.

## Step 3: Fix the port

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

<!-- OUTPUT PENDING: peerauthentication.security.istio.io/probe configured -->

## Step 4: Prove it works

Send signals from the drifter to the probe and to cargo, and from the shuttle to both:

```sh
kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter -> probe: %{http_code}\n' --max-time 5 http://probe.starfleet:8000/get
kubectl -n outpost exec deploy/drifter -- curl -s -o /dev/null -w 'drifter -> cargo: %{http_code}\n' --max-time 5 http://cargo.starfleet:9080/details/0
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle -> probe: %{http_code}\n' http://probe:8000/get
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w 'shuttle -> cargo: %{http_code}\n' http://cargo:9080/details/0
```

<!-- OUTPUT PENDING: drifter -> probe: 200; drifter -> cargo: 000 with exit code 56; shuttle -> probe: 200; shuttle -> cargo: 200 -->

The drifter now reaches the probe, and `cargo` still refuses it. Only the probe's port accepts plain signals. The shuttle does the handshake, so it reaches both.

If the drifter still gets `000` from the probe, the new orders have not reached the probe's proxy yet. Wait a few seconds and send the signal again.

Now submit:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-02
```

---

## Common Mistakes

- **Setting the whole probe to `PERMISSIVE`.** The drifter gets through, but the task asks to keep the workload `STRICT` and open only the port. The grader checks the workload mode.
- **Changing the `default` policy.** Setting the planet to `PERMISSIVE` also lets the drifter reach `cargo`. The grader checks that `cargo` still refuses it.
- **Giving the drifter a sidecar.** Labelling `outpost` and restarting the drifter also fixes the signal, but the drifter must stay outside the mesh.
- **Writing a second policy for the probe.** Keep one policy per workload. Two policies that select the same pods give results that are hard to predict.
