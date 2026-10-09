# Solution Walkthrough

Three objects do the work, in this order: the Secret where the gateway pod can read it, the `Gateway` with an HTTPS server and a redirect server, and the `VirtualService` that sends `/book` to the booking service. Then you prove it with real requests.

---

## Step 1: Put the credential where the gateway looks

The gateway pod runs in `istio-system`, so the Secret goes there, not in `tls-demo`. `kubectl create secret tls` makes exactly the two key names Istio reads:

```sh
kubectl -n istio-system create secret tls booking-credential \
  --key=/tmp/booking.key --cert=/tmp/booking.crt
```

```text
secret/booking-credential created
```

Check the key names:

```sh
kubectl -n istio-system get secret booking-credential \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

```text
tls.crt
tls.key
```

A Secret next to the `Gateway` object, in `tls-demo`, would be accepted by Kubernetes and never delivered to the gateway.

---

## Step 2: Add the HTTPS server and the redirect server

Save this as `gateway-booking.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f gateway-booking.yaml
```

```text
gateway.networking.istio.io/booking-gateway created
```

The selector `istio: ingressgateway` matches the gateway that the `demo` profile installs. The first server ends TLS with the certificate from `booking-credential`. The second server needs no certificate: `httpsRedirect: true` answers every plain HTTP request with a redirect.

---

## Step 3: Route `/book` to the booking service

Save this as `virtualservice-booking.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f virtualservice-booking.yaml
```

```text
virtualservice.networking.istio.io/booking created
```

Then check that the gateway really holds the credential:

```sh
istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system | grep booking-credential
```

```text
kubernetes://booking-credential     CA             ACTIVE     true           6082c7d04bc63943a8267909f155859c0edc5813     2027-10-09T09:37:09Z     2026-10-09T09:37:09Z
```

`ACTIVE` means `istiod` delivered the Secret to the gateway. The type says `CA` because this certificate signed itself, so it is also marked as a certificate authority; that does not matter here. Your serial number and dates differ. `WARMING`, or no row at all, means the Secret is in the wrong namespace or has the wrong name.

---

## Step 4: Test HTTPS, with the right SNI

Start a port forward to the gateway in the background:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 8080:80 >/dev/null 2>&1 &
```

Then send an HTTPS request and read the certificate the gateway showed:

```sh
curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
  -o /dev/null -w 'https: %{http_code}\n' https://booking.ica.local:8443/book
curl -sk -v --resolve booking.ica.local:8443:127.0.0.1 \
  https://booking.ica.local:8443/book 2>&1 | grep -E 'subject:|issuer:'
```

```text
https: 200
*  subject: CN=booking.ica.local; O=ica
*  issuer: CN=booking.ica.local; O=ica
```

`--resolve` connects to your port forward while still sending `booking.ica.local` as the SNI and the `Host` header. The SNI (server name indication) picks the HTTPS server; the `Host` header picks the route. `-k` accepts the self-signed certificate. Subject and issuer are the same because the certificate signed itself.

---

## Step 5: Test the redirect

Plain HTTP has no SNI, so a `Host` header is enough:

```sh
curl -s -o /dev/null -w 'http: %{http_code}\n' -H "Host: booking.ica.local" http://127.0.0.1:8080/book
```

```text
http: 301
```

Stop the port forward when you are done: `kill %1`.

---

## Step 6: Submit

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

---

## If it does not pass

- **The handshake fails.** Run `istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system`. A missing or `WARMING` `booking-credential` means the Secret is in the wrong namespace or has the wrong key names.
- **`404` over a working TLS connection.** TLS is fine; the `VirtualService` is the problem. Check its `hosts` and its `gateways` entry.
- **Port 80 returns `200`.** The redirect server is missing, or it routes instead of redirecting.
