# Solution Walkthrough

Mission debrief, astronaut. Two faults stacked on top of each other. The gate listened for a host with one letter missing, and the flight plan was an `http` block, which a gate with no key can never match. Either one alone leaves the stream with nowhere to go.

---

## Step 1: Confirm the failure

Open the port forward to the gate, then send one signal with the vault's SNI name:

```sh
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
sleep 2
curl -sk --resolve vault.starfleet.example.com:8443:127.0.0.1 \
  -o /dev/null -w "%{http_code}\n" https://vault.starfleet.example.com:8443/
```

```text
000
```

`000` means the connection ended before any HTTP reply. A broken passthrough setup never sends a `404` or a `403`, because the gate would have to read the request to send one. The failed handshake also ends your `kubectl port-forward`. Start it again with the same command before the next signal.

## Step 2: Read the gate's listener

Ask the gate which SNI names its port 443 listener knows:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress --port 443
```

```text
ADDRESSES PORT MATCH DESTINATION
```

Only the header row: the gate has no listener on port `443` at all, so it cannot route any SNI name there. Now look at the two objects:

```sh
kubectl get gateways.networking.istio.io vault-gateway -n starfleet -o jsonpath='{.spec.servers[0].hosts}{"\n"}'
kubectl get virtualservice tls-backend -n starfleet -o yaml | grep -A8 '^spec:'
```

```text
["valt.starfleet.example.com"]
spec:
  gateways:
  - vault-gateway
  hosts:
  - vault.starfleet.example.com
  http:
  - route:
    - destination:
        host: tls-backend
```

`istioctl analyze -n starfleet` points at the first fault too: `Warning [IST0132] (VirtualService starfleet/tls-backend) one or more host [vault.starfleet.example.com] defined in VirtualService starfleet/tls-backend not found in Gateway starfleet/vault-gateway.` It says nothing about the `http` block.

Two faults show up:

- The `Gateway` listens for `valt.starfleet.example.com`. The visitor sends `vault.starfleet.example.com`.
- The `VirtualService` has an `http` block. An `http` rule needs a method, a path or a header, and the gate can read none of them in a sealed stream.

## Step 3: Fix the Gateway

Save this as `gateway-vault.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: vault-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - vault.starfleet.example.com
    tls:
      mode: PASSTHROUGH
```

Apply it:

```sh
kubectl apply -f gateway-vault.yaml
```

```text
gateway.networking.istio.io/vault-gateway configured
```

If you submit now, the grader still fails with `the VirtualService still has an http block`.

## Step 4: Fix the VirtualService

Save this as `virtualservice-tls-backend.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tls-backend
  namespace: starfleet
spec:
  hosts:
  - vault.starfleet.example.com
  gateways:
  - vault-gateway
  tls:
  - match:
    - port: 443
      sniHosts:
      - vault.starfleet.example.com
    route:
    - destination:
        host: tls-backend
        port:
          number: 8443
```

Apply it:

```sh
kubectl apply -f virtualservice-tls-backend.yaml
```

```text
virtualservice.networking.istio.io/tls-backend configured
```

The `tls` block matches on `sniHosts`, the address on the envelope. The old `http` block is gone, because `kubectl apply` removes fields that were in the last applied version and are missing from the new file.

## Step 5: Prove it works

Wait about a minute for the gate to get its new orders. Start the port forward again, then send the signal, read the reply, and read the certificate it came with:

```sh
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
sleep 2
curl -sk --resolve vault.starfleet.example.com:8443:127.0.0.1 \
  -o /dev/null -w "%{http_code}\n" https://vault.starfleet.example.com:8443/
curl -sk --resolve vault.starfleet.example.com:8443:127.0.0.1 https://vault.starfleet.example.com:8443/
openssl s_client -connect 127.0.0.1:8443 -servername vault.starfleet.example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject
```

```text
200
vault ended TLS itself
subject=CN=vault.starfleet.example.com, O=vault
```

The certificate is the vault's own, so the vault ended TLS, not the gate. Last, check that the gate holds no HTTP route for the host:

```sh
istioctl proxy-config routes deploy/istio-ingress -n istio-ingress | grep vault.starfleet.example.com \
  || echo "no HTTP route for vault.starfleet.example.com, as expected in passthrough"
```

```text
no HTTP route for vault.starfleet.example.com, as expected in passthrough
```

Stop the port forward with `kill %1`, then submit:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-02
```

---

## Common Mistakes

- **Fixing only one fault.** With the host fixed and the `http` block still there, or the other way round, the connection still fails with `000`.
- **Changing `protocol` to `HTTPS` or adding a `credentialName`.** Neither belongs on a server that does not decrypt. The grader asks for `protocol: TLS`, no credential, and the vault's own certificate.
- **Writing `sniHosts` with a host that is not in the `VirtualService`'s `hosts`.** The `sniHosts` names must be among the `VirtualService`'s own hosts, and both must match the `Gateway`.
- **Testing without `--resolve`.** A signal to `127.0.0.1` carries no SNI name, so it fails with any setup.
