# Step-by-Step Guide: LAB015-040-03

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Confirm the backend owns its certificate

Before any gateway exists, talk to the backend directly:

```sh
kubectl -n passthrough-demo port-forward svc/tls-backend 9443:8443 >/dev/null 2>&1 &
sleep 2
curl -sk -v https://localhost:9443/ 2>&1 | grep -E 'subject:|issuer:|backend'
kill %1
```

```text
* subject: CN=secure.ica.local; O=backend
* issuer: CN=secure.ica.local; O=backend
backend terminated TLS
```

Keep that subject line. If the same certificate comes back through the gateway
later, nothing in between re-created it.

## Step 2: A listener that does not decrypt

Write the manifest to a file and apply the file. It is the habit the exam rewards — you get something you can re-read, edit and re-apply, instead of a heredoc that is gone the moment it runs.

```sh
cat > gateway-passthrough-gateway.yaml <<'YAML'
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
YAML
kubectl apply -f gateway-passthrough-gateway.yaml
```

Three differences from a terminating listener, and each is a consequence:
`protocol: TLS` rather than `HTTPS` (which would mean "terminate and parse HTTP
inside"), a port name that agrees with the protocol, and no `credentialName` —
there is nothing for the gateway to present.

## Step 3: Route on SNI

```sh
cat > virtualservice-passthrough.yaml <<'YAML'
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
YAML
kubectl apply -f virtualservice-passthrough.yaml
```

A `tls` block, not an `http` block. An `http` match needs a method, a path or a
header, and the gateway has none of those — the bytes after the ClientHello are
opaque. Writing `http` here applies cleanly, passes `istioctl analyze`, and every
connection fails.

`sniHosts` must name the same hostname the `Gateway` lists in `hosts`; both match
the same value out of the same handshake. The destination port is the backend's
**TLS** port.

## Step 4: Prove the gateway did not terminate

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
* subject: CN=secure.ica.local; O=backend
* issuer: CN=secure.ica.local; O=backend
```

Same certificate as step 1. The TLS session was negotiated directly between your
`curl` and that nginx; the gateway moved bytes between two sockets.

The gateway's own configuration says the same thing by omission:

```sh
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system --port 443 -o json \
  | grep -i -E 'tls_inspector|serverNames' | head
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system | grep secure.ica.local \
  || echo "no HTTP route for secure.ica.local — expected in passthrough"
```

`tls_inspector` is the filter that peeks at the ClientHello to read SNI without
decrypting. The missing HTTP route is the mode working, not a fault.

Stop the port-forward with `kill %1`.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **The connection fails.** Most likely an `http` block instead of `tls`, or
  `hosts` and `sniHosts` disagreeing.
- **You get a certificate that is not `O=backend`.** Something is terminating —
  check for `protocol: HTTPS` or a stray `credentialName`.
- **It only fails without `--resolve`.** That is the test, not the config: with
  no SNI the routing rule has no input at all.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl proxy-config secret](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading the certificates a workload actually holds
- [istioctl analyze](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-analyze) — the cross-object checks and their IST codes
- [istioctl proxy-config](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — reading a proxy's live configuration
