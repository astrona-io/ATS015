# Solution Walkthrough

Mission debrief, astronaut. One arrival gate, three listeners. Two listeners share port `443`, and the gate picks between them by the address on the sealed envelope (SNI). One opens the signal with your badge and key. The other forwards it unopened.

---

## Step 1: The gate's badge, for the terminated hostname only

The gate reads its badge and key from a Secret in its own namespace, `istio-system`. Create it from the files the setup left in `/tmp`:

```sh
kubectl -n istio-system create secret tls booking-credential \
  --key=/tmp/booking.key --cert=/tmp/booking.crt
```

<!-- OUTPUT PENDING: expect "secret/booking-credential created" -->

The passthrough hostname gets no Secret. The gate never opens those signals, so it has nothing to present.

---

## Step 2: One gateway, three listeners

Save this as `gateway-edge-gateway.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f gateway-edge-gateway.yaml
```

Two listeners share port `443`, told apart by `hosts`. The gate reads the SNI from the first message of the TLS handshake, before anything is opened. That is why the mode is chosen per listener, not per gateway.

`protocol: HTTPS` means "open it and treat the contents as HTTP". `protocol: TLS` means "a sealed stream", with no promise about what is inside.

---

## Step 3: Two flight plans

The terminated hostname uses an `http` block, because the gate can see a method and a path.

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
```

Apply it:

```sh
kubectl apply -f virtualservice-booking.yaml
```

The passthrough hostname uses a `tls` block on `sniHosts`, because the envelope address is the only thing the gate can read.

Save this as `virtualservice-passthrough.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f virtualservice-passthrough.yaml
```

An `http` block on the passthrough hostname would apply without an error and route nothing.

---

## Step 4: Prove each hostname separately

Open two port-forwards to the gate, then call each hostname. `--resolve` makes `curl` send the right SNI to `127.0.0.1`:

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

`O=ica` on one hostname and `O=backend` on the other tells the whole story. The gate showed your badge for one hostname and never held a key for the other. A `200` alone proves nothing here: it looks the same in both modes.

Stop the port-forwards with `kill %1 %2`.

Now submit:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

---

## Common Mistakes

- **The Secret is in `tls-demo`.** The gate reads credentials from its own namespace, `istio-system`. The handshake for `booking.ica.local` then fails.
- **`secure.ica.local` gets the `CN=booking.ica.local` certificate.** SNI matched the wrong listener. Check the `hosts` on each `servers` entry.
- **`secure.ica.local` does not connect.** Most often an `http` block in its `VirtualService`, or `protocol: HTTPS` on its listener.
- **`booking.ica.local` returns `404`.** TLS works, but its `VirtualService` does not route: check `gateways` and the `/book` prefix.
- **Testing without `--resolve`.** Without the hostname in the request, `curl` sends no matching SNI and the gate cannot pick a listener.
