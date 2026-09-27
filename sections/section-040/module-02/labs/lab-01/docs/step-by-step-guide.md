# Step-by-Step Guide: LAB015-040-02

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Understand the material

```sh
openssl x509 -in /tmp/client.crt -noout -subject -issuer
```

```text
subject=CN = client.ica.local, O = ica
issuer=CN = ica-ca, O = ica
```

The client certificate's **subject** is the client; its **issuer** is the CA.
That relationship is the entire verification — the gateway will accept any
certificate whose chain reaches `ica-ca`, and reject everything else.

## Step 2: Build the three-key secret

```sh
kubectl -n istio-system create secret generic booking-credential-mtls \
  --from-file=tls.crt=/tmp/booking.crt \
  --from-file=tls.key=/tmp/booking.key \
  --from-file=ca.crt=/tmp/ca.crt

kubectl -n istio-system get secret booking-credential-mtls \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

```text
ca.crt
tls.crt
tls.key
```

`kubectl create secret tls` accepts only a certificate and a key — there is no
flag for a CA — so this one is built with `create secret generic` and explicit
key names. The `key=path` form of `--from-file` is what sets the key inside the
secret independently of the filename; without it you would get a key called
`booking.crt`.

Check those three names before testing traffic. Getting them wrong is not an
error, and the result is a gateway that verifies nobody.

## Step 3: Turn on MUTUAL

```sh
kubectl apply -f - <<'YAML'
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
---
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
YAML
```

## Step 4: Confirm verification is armed

Do this **before** trusting a successful request:

```sh
istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential-mtls
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system --port 443 -o json \
  | grep -i requireClientCertificate
```

```text
kubernetes://booking-credential-mtls     Cert Chain     ACTIVE     true ...
    "requireClientCertificate": true,
```

If the secret is listed but this says `false`, `ca.crt` is missing or misnamed.

## Step 5: Test both clients

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
curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required
no cert:   000
with cert: 200
```

The first call fails during the handshake. The exact message varies with the
client's OpenSSL version; `certificate required` and `000` are the constants. No
request was ever sent, so no route and no policy was involved.

Stop the port-forward with `kill %1`.

## Step 6: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Both calls return `200`.** `requireClientCertificate` is `false` — the CA key
  is missing or misnamed. This is the failure that looks like success.
- **Both calls fail the handshake.** The server certificate or key is wrong, or
  the secret is in the wrong namespace.
- **The certificate call gets `404`.** TLS and verification are both fine; the
  `VirtualService` is not routing.
