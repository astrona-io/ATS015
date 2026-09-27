# Step-by-Step Guide: LAB015-040-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Put the credential where the gateway looks

```sh
kubectl -n istio-system create secret tls booking-credential \
  --key=/tmp/booking.key --cert=/tmp/booking.crt

kubectl -n istio-system get secret booking-credential \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

```text
tls.crt
tls.key
```

`istio-system`, not `tls-demo`. The gateway pod runs there and fetches its
credentials from its own namespace; a secret next to the `Gateway` object is
never seen. `create secret tls` produces exactly the two key names Istio expects.

## Step 2: Gateway and VirtualService

```sh
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: booking-gateway
  namespace: tls-demo
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
        mode: SIMPLE
        credentialName: booking-credential
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - booking.ica.local
      tls:
        httpsRedirect: true
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: tls-demo
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

`protocol: HTTPS` and a port name starting `https` are both load-bearing — Istio
derives part of its protocol handling from the name prefix, so `web` or
`tls-port` would produce a different listener.

## Step 3: Test it, with SNI

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
sleep 2
curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
  -o /dev/null -w 'https: %{http_code}\n' https://booking.ica.local:8443/book

curl -sk -v --resolve booking.ica.local:8443:127.0.0.1 \
  https://booking.ica.local:8443/book 2>&1 | grep -E 'subject:|issuer:'
```

```text
https: 200
* subject: CN=booking.ica.local; O=ica
* issuer: CN=booking.ica.local; O=ica
```

`--resolve` connects to localhost while still sending `booking.ica.local` as SNI
and `Host`. SNI selects the listener; the `Host` header selects the route.

## Step 4: Test the redirect

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
sleep 2
curl -s -o /dev/null -w 'http: %{http_code}\n' -H "Host: booking.ica.local" http://localhost:8080/book
```

```text
http: 301
```

Plain HTTP needs no `--resolve` — there is no SNI involved.

Stop both port-forwards when you are done: `jobs` then `kill %1 %2`.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **The handshake fails.** Check `istioctl proxy-config secret
  deploy/istio-ingressgateway -n istio-system | grep booking-credential`. Nothing
  listed means the secret is in the wrong namespace or has the wrong key names.
- **`404` over a working TLS connection.** TLS is fine; the `VirtualService` is
  the problem — check its `hosts` and its `gateways` entry.
- **Port 80 returns `200`.** The redirect listener is missing, or it routes
  instead of redirecting.
