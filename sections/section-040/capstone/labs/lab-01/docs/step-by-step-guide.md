# Step-by-Step Guide: CAP015-040

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: The credential, for the terminated hostname only

```sh
kubectl -n istio-system create secret tls booking-credential \
  --key=/tmp/booking.key --cert=/tmp/booking.crt
```

`istio-system`, because the gateway pod fetches credentials from its own
namespace. The passthrough hostname gets nothing — there is nothing for the
gateway to present.

## Step 2: One gateway, three listeners

```sh
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: tls-demo
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-booking
        protocol: HTTPS
      hosts:
        - booking.ica.local
      tls:
        mode: SIMPLE
        credentialName: booking-credential
    - port:
        number: 443
        name: tls-secure
        protocol: TLS
      hosts:
        - secure.ica.local
      tls:
        mode: PASSTHROUGH
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - booking.ica.local
      tls:
        httpsRedirect: true
YAML
```

Two listeners on the same port, distinguished by `hosts` — and the gateway picks
between them by **SNI**, read out of the ClientHello before anything is
decrypted. That is also why the modes are a per-listener choice: nothing about
this is decided per gateway.

`protocol: HTTPS` means terminate and treat the contents as HTTP. `protocol:
TLS` means "a TLS stream", with no claim about what is inside.

## Step 3: Two routing sections

```sh
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: tls-demo
spec:
  hosts:
    - booking.ica.local
  gateways:
    - edge-gateway
  http:
    - match:
        - uri:
            prefix: /book
      route:
        - destination:
            host: booking-service
            port:
              number: 80
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: tls-demo
spec:
  hosts:
    - secure.ica.local
  gateways:
    - edge-gateway
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
```

The terminated host uses an `http` block, because the gateway can see a method
and a path. The passthrough host uses a `tls` block on `sniHosts`, because SNI is
the only thing it can read. An `http` block there would apply cleanly and route
nothing.

## Step 4: Prove each hostname separately

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80  >/dev/null 2>&1 &
sleep 3

curl -sk -v --resolve booking.ica.local:8443:127.0.0.1 https://booking.ica.local:8443/book 2>&1 \
  | grep -E 'subject:|HTTP/'
curl -sk -v --resolve secure.ica.local:8443:127.0.0.1  https://secure.ica.local:8443/ 2>&1 \
  | grep -E 'subject:|HTTP/'
curl -s -o /dev/null -w 'http: %{http_code}\n' -H "Host: booking.ica.local" http://localhost:8080/book
```

```text
* subject: CN=booking.ica.local; O=ica
< HTTP/2 200
* subject: CN=secure.ica.local; O=backend
< HTTP/1.1 200 OK
http: 301
```

`O=ica` on one and `O=backend` on the other is the whole capstone in two lines:
the gateway presented your certificate for one hostname and never held a key for
the other.

Stop the port-forwards: `kill %1 %2`.

## Step 5: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **`secure.ica.local` is served a `CN=booking.ica.local` certificate.** SNI
  matched the wrong listener — check the `hosts` on each `servers` entry.
- **`secure.ica.local` fails to connect.** Most likely an `http` block in its
  `VirtualService`, or `protocol: HTTPS` on its listener.
- **`booking.ica.local` gets `404`.** TLS is fine; its `VirtualService` is not
  routing.
