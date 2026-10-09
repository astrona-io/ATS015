# Solution Walkthrough

The gateway needed one secret with three keys, in the gateway pod's own namespace, and a server that asks every client for a client certificate. Then you proved the check from the gateway's own proxy, not only from a request that worked.

---

## Step 1: Look at the certificates

Read the client certificate's subject and issuer:

```sh
openssl x509 -in /tmp/client.crt -noout -subject -issuer
```

```text
subject=CN=client.ica.local, O=ica
issuer=CN=ica-ca, O=ica
```

This is the format of OpenSSL 3. Other versions space or order the fields slightly differently.

The **subject** is the client. The **issuer** is the CA. The gateway will accept any certificate signed by `ica-ca`, and refuse every other one.

## Step 2: Build the three-key secret

The ingress gateway pod runs in `istio-system`, and it reads `credentialName` from its own namespace only. So the secret goes there.

`kubectl create secret tls` takes only a certificate and a key. It has no flag for a CA, so build a generic secret and name every key yourself:

```sh
kubectl -n istio-system create secret generic booking-credential-mtls \
  --from-file=tls.crt=/tmp/booking.crt \
  --from-file=tls.key=/tmp/booking.key \
  --from-file=ca.crt=/tmp/ca.crt
```

```text
secret/booking-credential-mtls created
```

Check the key names before you test any traffic:

```sh
kubectl -n istio-system get secret booking-credential-mtls \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

```text
ca.crt
tls.crt
tls.key
```

The `name=path` form of `--from-file` sets the key name inside the secret. Without it you would get a key called `booking.crt`, which the gateway does not look for.

## Step 3: Switch the gateway to `MUTUAL`

Save this as `gateway-booking.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: booking-gateway
  namespace: mtlsedge-demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - booking.ica.local
    tls:
      mode: MUTUAL
      credentialName: booking-credential-mtls
```

Apply it:

```sh
kubectl apply -f gateway-booking.yaml
```

```text
gateway.networking.istio.io/booking-gateway created
```

Then the `VirtualService` that routes requests from the gateway to the service. Save this as `virtualservice-booking.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: mtlsedge-demo
spec:
  hosts:
  - booking.ica.local
  gateways:
  - booking-gateway
  http:
  - match:
    - uri:
        prefix: /book
    route:
    - destination:
        host: booking-service
        port:
          number: 80
```

Apply it:

```sh
kubectl apply -f virtualservice-booking.yaml
```

```text
virtualservice.networking.istio.io/booking created
```

## Step 4: Prove the check is on

Do this before you trust a request that works. `istiod`, Istio's control plane, needs a moment to send the new configuration to the gateway, so wait about a minute after the apply. First, the certificates the gateway holds:

```sh
istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential-mtls
```

```text
kubernetes://booking-credential-mtls            Cert Chain     ACTIVE     true           55ed629ccc887fd57cdac869718cecbc4d9a707b     2036-09-24T19:42:09Z     2026-09-27T19:42:09Z
kubernetes://booking-credential-mtls-cacert     CA             ACTIVE     true           d497de97637f0a3501f7632475361bfa8e16317      2036-09-24T19:42:09Z     2026-09-27T19:42:09Z
```

Both rows must be `ACTIVE`. The `-cacert` row is the CA the gateway checks clients against. `WARMING` means the gateway never got it: the secret is missing, in the wrong namespace, or has no `ca.crt`.

Then the listener:

```sh
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system -o json \
  | grep requireClientCertificate
```

```text
                        "requireClientCertificate": true
```

`true` means the listener asks every client for a certificate.

## Step 5: Test both clients

Start the port forward, then call without and with the client certificate:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
sleep 2
curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
  https://booking.ica.local:8443/book -o /dev/null -w 'no cert:   %{http_code}\n'
curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
  --cert /tmp/client.crt --key /tmp/client.key \
  https://booking.ica.local:8443/book -o /dev/null -w 'with cert: %{http_code}\n'
```

```text
no cert:   000
with cert: 200
```

The first call is refused during the TLS handshake. No request was ever sent, so there is no status code, and no route or policy was involved. A refused handshake can end the port forward. If the second call also prints `000`, start the port forward again and repeat it. Stop the port forward with `kill %1` when you are done.

Now submit:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

---

## Common Mistakes

- **Both calls fail the handshake.** The gateway has no usable certificate. Check that the secret is in `istio-system` and that both `kubernetes://booking-credential-mtls` rows in `proxy-config secret` are `ACTIVE`.
- **Both calls return `200`.** The `Gateway` still says `SIMPLE`, or the listener shows `requireClientCertificate` as missing. Check `tls.mode`.
- **The call with a certificate gets `404`.** TLS and the client check both work. The `VirtualService` is not routing: check its `hosts`, its `gateways` and the `/book` match.
- **Using `kubectl create secret tls`.** It cannot add `ca.crt`. Use `kubectl create secret generic` with explicit key names.
