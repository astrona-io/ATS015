# Practice: Let Only Badged Partners Through The Gate

An exam-style mission for this playground, astronaut. Start the playground
first, make the certificates in `certs/` and paste the `https_status` helper
from [overview.md](./overview.md#helper). The solution uses both.

Try the task on your own first, then open the solution. The solution was run
and checked on a real cluster. If you worked through the module first, clear
the old objects with the commands under "Start over without a new cluster" in
[overview.md](./overview.md) before you begin.

## Task: badges on 443, a redirect on 80

> Serve `starfleet.example.com` through the ingress gateway so that only
> clients with a certificate signed by the CA in `certs/example.com.crt` can
> reach the bridge's `/productpage`. Use the server certificate in
> `certs/starfleet.example.com.crt` and a secret named **`starfleet-mtls`**.
> Use a `Gateway` named `starfleet-gateway` and a `VirtualService` named
> `bridge`, both in `starfleet`. Plain HTTP on port `80` must redirect to
> HTTPS.

<details><summary>Solution</summary>

The gate needs one secret with three keys, on its own planet. `kubectl create
secret tls` cannot add the CA, so build it as a generic secret:

```sh
kubectl create -n istio-ingress secret generic starfleet-mtls \
  --from-file=tls.key=certs/starfleet.example.com.key \
  --from-file=tls.crt=certs/starfleet.example.com.crt \
  --from-file=ca.crt=certs/example.com.crt
```

```text
secret/starfleet-mtls created
```

Then open the gate. Save this as `gateway-starfleet.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: starfleet-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - starfleet.example.com
    tls:
      mode: MUTUAL
      credentialName: starfleet-mtls
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - starfleet.example.com
    tls:
      httpsRedirect: true
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway created
```

Then write the flight plan. Save this as `virtualservice-bridge.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: bridge
  namespace: starfleet
spec:
  hosts:
  - starfleet.example.com
  gateways:
  - starfleet-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    route:
    - destination:
        host: bridge
        port:
          number: 9080
```

Apply it:

```sh
kubectl apply -f virtualservice-bridge.yaml
```

```text
virtualservice.networking.istio.io/bridge created
```

Then check the result. Wait about a minute for the gate to get its orders, then knock with a good badge, without a badge, and with plain HTTP:

```sh
https_status --cert certs/client.example.com.crt --key certs/client.example.com.key
https_status
curl -s -o /dev/null -w "%{http_code}\n" --resolve starfleet.example.com:8080:127.0.0.1 \
  http://starfleet.example.com:8080/productpage
```

```text
200 exit=0
000 exit=56
301
```

The badged visitor reaches the bridge. The visitor without a badge is turned
away in the handshake, so there is no status code. The refused handshake
restarts the `8443` port forward for a few seconds; the plain HTTP signal
uses the other forward, on `8080`, so it is not affected. Plain HTTP gets a `301`
redirect to the `https://` address. The redirect needs no badge, because it
happens on port `80`, where there is no TLS at all.

</details>
