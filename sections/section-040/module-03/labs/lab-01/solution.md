# Solution Walkthrough

Two objects do the whole job: a `Gateway` server that does not decrypt, and a `VirtualService` that routes on the SNI (Server Name Indication) name, the host name the client sends in clear text. The proof is the certificate the client gets.

---

## Step 1: Confirm the backend owns its certificate

Before any gateway setting exists, talk to the backend directly, with a port forward to its Service:

```sh
kubectl -n passthrough-demo port-forward svc/tls-backend 9443:8443 >/dev/null 2>&1 &
sleep 2
curl -sk -v https://localhost:9443/ 2>&1 | grep -E 'subject:|issuer:|backend'
kill %1
```

```text
*  subject: CN=secure.ica.local; O=backend
*  issuer: CN=secure.ica.local; O=backend
backend terminated TLS
```

Keep that subject line. If the same certificate comes back through the gateway later, nothing in between made a new one.

## Step 2: A server that does not decrypt

Save this as `gateway-passthrough-gateway.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: passthrough-gateway
  namespace: passthrough-demo
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: tls
        protocol: TLS
      hosts:
        - secure.ica.local
      tls:
        mode: PASSTHROUGH
```

Apply it:

```sh
kubectl apply -f gateway-passthrough-gateway.yaml
```

```text
gateway.networking.istio.io/passthrough-gateway created
```

Three fields differ from a server that ends TLS, and each one follows from "the gateway has no key":

- `protocol: TLS`, not `HTTPS`. `HTTPS` would say "end TLS here and read the HTTP inside", which is not what this server does.
- The port name `tls` agrees with the protocol.
- No `credentialName`. The gateway shows no certificate of its own, so it needs no secret.

## Step 3: Route on the SNI name

Save this as `virtualservice-passthrough.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: passthrough-demo
spec:
  hosts:
    - secure.ica.local
  gateways:
    - passthrough-gateway
  tls:
    - match:
        - port: 443
          sniHosts:
            - secure.ica.local
      route:
        - destination:
            host: tls-backend
            port:
              number: 8443
```

Apply it:

```sh
kubectl apply -f virtualservice-passthrough.yaml
```

```text
virtualservice.networking.istio.io/passthrough created
```

This is a `tls` block, not an `http` block. An `http` rule needs a method, a path or a header, and the gateway can read none of them: everything after the first handshake message is encrypted. An `http` block here applies cleanly, and every connection fails.

`sniHosts` names the same host as the `Gateway`'s `hosts`, because both read the same value from the same handshake. The destination port is the backend's **TLS** port, `8443`.

## Step 4: Prove the gateway did not end TLS

Wait about a minute for `istiod`, Istio's control plane, to push the new configuration to the gateway. Open the port forward to the gateway, then send one request with the SNI name and read the certificate it comes with:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
sleep 2
curl -sk --resolve secure.ica.local:8443:127.0.0.1 \
  -o /dev/null -w 'passthrough: %{http_code}\n' https://secure.ica.local:8443/
curl -sk -v --resolve secure.ica.local:8443:127.0.0.1 \
  https://secure.ica.local:8443/ 2>&1 | grep -E 'subject:|issuer:'
```

```text
passthrough: 200
*  subject: CN=secure.ica.local; O=backend
*  issuer: CN=secure.ica.local; O=backend
```

It is the same certificate as in step 1. Your `curl` and the backend's nginx agreed on the key between them, and the gateway only moved bytes from one connection to the other.

The gateway's own configuration says the same thing. Its listener matches on the SNI name, and it has no HTTP route for the host. In the `demo` profile the gateway Service sends port `443` to port `8443` on the gateway pod, so the listener sits on `8443`:

```sh
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system --port 8443
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system | grep secure.ica.local \
  || echo "no HTTP route for secure.ica.local, as expected in passthrough"
```

```text
ADDRESSES PORT MATCH                 DESTINATION
0.0.0.0   8443 SNI: secure.ica.local Cluster: outbound|8443||tls-backend.passthrough-demo.svc.cluster.local
no HTTP route for secure.ica.local, as expected in passthrough
```

With `--port 443` you get only the header row. The pod's listener port is the Service's `targetPort`, not its `port`.

The missing HTTP route is the mode working, not a fault. Stop the port forward with `kill %1`.

Now submit:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

---

## Common Mistakes

- **An `http` block in the `VirtualService`.** It applies cleanly and every connection fails. Use a `tls` block that matches on `sniHosts`.
- **`hosts` and `sniHosts` naming different hosts.** Both read the same SNI name, so a mismatch routes nothing.
- **`protocol: HTTPS` or a `credentialName`.** A `credentialName` belongs to a server that ends TLS, and `HTTPS` says the gateway reads HTTP. Istio 1.30.5 still passes the stream through when the mode is `PASSTHROUGH`, but the task and the grader ask for `protocol: TLS` and no credential, because that is what really happens.
- **Testing without `--resolve`.** A request to `127.0.0.1` carries no SNI name, so the rule has no input. That is a fault in the test, not in the setup.
