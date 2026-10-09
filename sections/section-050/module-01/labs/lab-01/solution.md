# Solution Walkthrough

The key to this lab is the right address field. `ipBlocks` only ever sees the proxy in front of the gateway. `remoteIpBlocks` sees the client the proxy reported, and the gateway already trusts exactly one proxy.

---

## Step 1: Find out what the gateway sees

Open the port forward, send one request, and read the gateway's access log:

```sh
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
sleep 2
curl -s -o /dev/null -w "before: %{http_code}\n" -H "Host: booking.ica.local" http://127.0.0.1:8080/book
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=1
```

```text
before: 200
[2026-10-09T11:33:47.704Z] "GET /book HTTP/1.1" 200 - via_upstream - "-" 0 49 3 3 "10.244.0.8" "curl/8.7.1" "94692387-4ab6-99d0-be9c-fb6c5af8a4e5" "booking.ica.local" "10.244.0.9:8084" outbound|80||booking-service.gwauthz-demo.svc.cluster.local 10.244.0.8:49318 127.0.0.1:8080 127.0.0.1:40498 - -
```

Envoy writes the access log in small batches. If the line is missing, wait a few seconds and run the `kubectl logs` command again.

The last address on the log line, `127.0.0.1:40498`, is the connection peer. It is `127.0.0.1`: the port forward ends inside the gateway pod. That is the same situation as a load balancer in production, and it is why `ipBlocks` is the wrong field here.

## Step 2: Confirm the gateway trusts one proxy

Ask the gateway's own listener, where Envoy holds the setting:

```sh
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system -o json | grep xffNumTrustedHops
```

```text
                            "xffNumTrustedHops": 1,
```

With `1`, the gateway takes the **last** entry of `X-Forwarded-For` as the client address. Anything a client wrote further left is ignored. Without this setting, the gateway would ignore the header and `remoteIpBlocks` would see the proxy too.

## Step 3: Write the policy

Find the gateway's label first, so the selector matches a real pod:

```sh
kubectl -n istio-system get pods -L istio | grep gateway
```

```text
istio-egressgateway-b7dd4655b-qrr27     1/1     Running   0          2m5s    egressgateway
istio-ingressgateway-85df8fd774-fj6tn   1/1     Running   0          116s    ingressgateway
```

The `demo` profile also runs an egress gateway. The policy must select the ingress one: `istio: ingressgateway`.

Save this as `authorizationpolicy-gateway-ip-deny.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-deny
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: DENY
  rules:
  - from:
    - source:
        remoteIpBlocks:
        - 192.168.0.0/16
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-ip-deny.yaml
```

Three choices matter here:

- **`namespace: istio-system`.** A selector only looks at pods in the policy's own namespace, and the gateway pod does not run in `gwauthz-demo`.
- **`istio: ingressgateway`.** That is the label of the `demo` profile's gateway.
- **`action: DENY`.** A block-list removes one range. An `ALLOW` policy would deny every request its rules do not match, on every host this shared gateway serves.

## Step 4: Test both clients

Wait about a minute, so the gateway gets its new configuration. Then send one request from each client:

```sh
curl -s -o /dev/null -w 'xff 10.1.2.3:    %{http_code}\n' \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: 10.1.2.3" http://127.0.0.1:8080/book
curl -s -o /dev/null -w 'xff 192.168.5.5: %{http_code}\n' \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: 192.168.5.5" http://127.0.0.1:8080/book
```

```text
xff 10.1.2.3:    200
xff 192.168.5.5: 403
```

Two requests that differ only in one header get different answers. The `403` is a normal denial with a body: the gateway accepted the connection, read the request, and denied it.

Setting `X-Forwarded-For` by hand works here because your `curl` acts as the single trusted proxy. In production the trusted proxy is a load balancer you control.

Stop the port forward with `kill %1`, then submit:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

---

## Common Mistakes

- **Both requests get `200`.** The policy is in the wrong namespace, or its selector matches no pod. Check `kubectl get authorizationpolicy -A` and the gateway's labels.
- **Both requests get `403`.** The policy is probably an `ALLOW` that closed the gateway, or the range is wider than intended.
- **`ipBlocks` instead of `remoteIpBlocks`.** `ipBlocks` reads the connection peer (`127.0.0.1` here), never the header, so `192.168.5.5` is never matched.
- **Reinstalling Istio to "set" `numTrustedProxies`.** It is already set. `meshConfig.gatewayTopology.numTrustedProxies` is not a real setting and is ignored; a reinstall can also remove the working one.
