# Practice: Two Modes On One Gate

An exam-style mission for this playground, astronaut. Start the playground
first, and paste the `tls_status` and `show_certificate` helpers from
[overview.md](./overview.md#helpers). The solution uses them.

Try the task on your own first, then open the solution.

## Task: one Gateway, one sealed host, one opened host

> In namespace `starfleet`, create **one** `Gateway` named `edge-gateway` on
> the ingress gateway (`istio: ingress`) with two servers on port `443`:
>
> 1. `starfleet.example.com`, where the gateway **ends** TLS itself with the
>    Secret `edge-credential` (create it from a self-signed certificate you make
>    with `openssl`), and the bridge answers `/productpage`.
> 2. `vault.starfleet.example.com`, where the gateway does **not** decrypt and
>    `tls-backend` (port `8443`) ends TLS with its own certificate.
>
> Use a `VirtualService` named `edge-bridge` and one named `edge-vault`. Prove
> that each host gets `200` and that the two hosts hand out different
> certificates. Delete `vault-gateway`, the `tls-backend` `VirtualService` and
> the HTTPS server you may have added to `starfleet-gateway` first, so only
> your new objects serve port `443`. (To drop that server, apply
> `starfleet-gateway` again with only its port `80` server.)

<details><summary>Solution</summary>

Make the gate's own badge and key first, and put them in the gate's safe. The
Secret must live in the gateway's namespace, `istio-ingress`:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=starfleet.example.com/O=edge-gate" \
  -addext "subjectAltName=DNS:starfleet.example.com" \
  -keyout edge.key -out edge.crt
kubectl create secret tls edge-credential -n istio-ingress --cert=edge.crt --key=edge.key
```

`openssl` prints a few lines of dots and plus signs while it makes the key. Then `kubectl` confirms the Secret:

```text
secret/edge-credential created
```

Save this as `gateway-edge.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
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
      credentialName: edge-credential
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - vault.starfleet.example.com
    tls:
      mode: PASSTHROUGH
```

Apply it:

```sh
kubectl apply -f gateway-edge.yaml
```

```text
gateway.networking.istio.io/edge-gateway created
```

Save this as `virtualservice-edge-bridge.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: edge-bridge
  namespace: starfleet
spec:
  hosts:
  - starfleet.example.com
  gateways:
  - edge-gateway
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

Save this as `virtualservice-edge-vault.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: edge-vault
  namespace: starfleet
spec:
  hosts:
  - vault.starfleet.example.com
  gateways:
  - edge-gateway
  tls:
  - match:
    - port: 443
      sniHosts:
      - vault.starfleet.example.com
    route:
    - destination:
        host: tls-backend
        port:
          number: 8443
```

Apply both:

```sh
kubectl apply -f virtualservice-edge-bridge.yaml -f virtualservice-edge-vault.yaml
```

```text
virtualservice.networking.istio.io/edge-bridge created
virtualservice.networking.istio.io/edge-vault created
```

Wait about a minute, then check the result:

```sh
tls_status starfleet.example.com /productpage
tls_status vault.starfleet.example.com
show_certificate starfleet.example.com
show_certificate vault.starfleet.example.com
```

```text
200
200
subject=CN=starfleet.example.com, O=edge-gate
sha256 Fingerprint=30:CF:86:93:55:95:E4:96:11:39:41:57:71:D0:ED:60:32:AC:3A:F5:3C:F8:0E:15:9D:F2:AC:D0:F9:9B:45:2B
subject=CN=vault.starfleet.example.com, O=vault
sha256 Fingerprint=8D:AA:16:3B:52:67:DB:24:B8:5B:4E:2E:AA:B1:76:CB:C3:40:76:49:68:C5:F9:3C:ED:C7:33:B6:1B:95:05:B4
```

One `Gateway` object, two servers on the same port, chosen by the address on
the envelope (SNI). The bridge's flight plan is an `http` block, because the
gate opened that signal. The vault's is a `tls` block, because the gate never
did.

</details>
