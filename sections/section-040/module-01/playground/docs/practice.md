# Practice: Serve The Bridge Over HTTPS

An exam-style mission for this playground, astronaut. Start the playground
first, make the test certificates and paste the `https_status` helper from
[overview.md](./overview.md#helper). The solution uses them.

Try the task on your own first, then open the solution.

## Task: put the arrival gate behind HTTPS

> Serve `starfleet.example.com` over HTTPS at the ingress gateway with a TLS
> Secret named **`starfleet-tls`** (use the certificate and key in `certs/`).
> Route `/productpage` to the `bridge` Service on port `9080`, and redirect
> plain HTTP on port `80` to HTTPS. Use a `Gateway` named `starfleet-gateway`
> and a `VirtualService` named `bridge`, both in namespace `starfleet`.

<details><summary>Solution</summary>

The Secret goes where the gateway pod runs, not where the `Gateway` lives.
Create it first:

```sh
kubectl create -n istio-ingress secret tls starfleet-tls \
  --key=certs/starfleet.example.com.key --cert=certs/starfleet.example.com.crt
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
      mode: SIMPLE
      credentialName: starfleet-tls
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

Then check the result: HTTPS first, then plain HTTP:

```sh
https_status
curl -s -o /dev/null -w "%{http_code}\n" --resolve starfleet.example.com:8080:127.0.0.1 \
  http://starfleet.example.com:8080/productpage
```

```text
200 exit=0
301
```

If the first line is not `200` right after the apply, wait ten seconds and run it again: the gate needs a moment to receive its orders.

HTTPS answers `200`, so the gateway loaded `starfleet-tls` and the flight plan
reaches the bridge. Plain HTTP gets `301`, so port `80` only sends callers to
HTTPS and serves nothing itself.

</details>
