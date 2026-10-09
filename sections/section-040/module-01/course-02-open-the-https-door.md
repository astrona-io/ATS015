# Open The HTTPS Door

Astronaut, the certificate waits in its Secret on the planet `istio-ingress`. In this part you write the `Gateway` server that asks for it, link a flight plan to the bridge, and send your first sealed signal through the gate. Then you prove which certificate the gate really showed, from both sides of the handshake.

## The TLS server

A `Gateway` opens ports on the ingress gateway. Each entry in its `servers` list is one door: a port, the host names it serves, and how it handles TLS. Here you write a door on port `443` that terminates TLS.

<!-- astrona:playground:renew -->

### Write the `Gateway`

Save this as `gateway-starfleet.yaml`:

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
      credentialName: starfleet-credential
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway created
```

### What each field does

- **`selector: istio: ingress`** picks the gateway pods that get this configuration, by pod label. The Helm gateway chart in this playground labels its pods `istio=ingress`. (An `istioctl install` gateway uses `istio=ingressgateway` instead.)
- **`protocol: HTTPS`** tells the gateway to end TLS on this port and then read the signal inside as HTTP. That is what lets a `VirtualService` route on paths.
- **`name: https`** is only a label for the port. By habit it repeats the protocol, but `protocol` decides how the gate treats the port: a door named `secure-door` works just the same.
- **`hosts`** lists the host names this door serves. The gateway compares it with the name the client asks for in the handshake.
- **`tls.mode: SIMPLE`** is ordinary one-way TLS: the gate shows a certificate, and the client shows none.
- **`credentialName`** is the Secret's name, looked up in the gateway pod's namespace.

Notice that the `Gateway` lives in `starfleet`, next to the bridge, while its Secret lives in `istio-ingress`. That split is correct.

## Link the flight plan

A `Gateway` only opens a door. A `VirtualService` that names the gateway in `gateways:` says where the signals that come through it fly next. Once the gateway has opened the seal, the signal is plain HTTP, so this flight plan looks the same as it would for an HTTP door.

### Write the `VirtualService`

Save this as `virtualservice-bridge.yaml`:

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
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
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

## Send a sealed signal

Now the whole path exists: Secret, door and flight plan. Send a signal through it with the `https_status` helper from the landing page, and then see why the helper needs `--resolve`.

### The first HTTPS signal

```sh
https_status
```

```text
200 exit=0
```

`200` is the bridge's answer, and `exit=0` means curl was happy with the handshake: it trusted the certificate and the name matched. Mission control needs a few seconds to send the gate its new orders, so if the first try fails right after the apply, wait ten seconds and run it again. If you keep getting `000 exit=7`, check the port forward with `astrona port-forward list`.

### What happened on the way

```mermaid
sequenceDiagram
    participant C as curl
    participant G as gateway
    participant B as bridge
    C->>G: hello, SNI starfleet.example.com
    G-->>C: certificate from starfleet-credential
    C->>G: HTTPS request, sealed
    G->>B: request over Istio mTLS
    B-->>G: response
    G-->>C: HTTPS response
```

The gateway Envoy in `istio-ingress` picks the certificate, opens the seal and sends the signal to the bridge, sealed again with the mesh's own mTLS.

### Why `--resolve` matters

In its very first message, the client writes the host name it wants on the outside of the envelope. That name is the **SNI** (server name indication). The gateway reads it to choose which server, and which certificate, answers. Only after the seal is open can it read the HTTP `Host` header and pick a route:

| What the gateway reads | When | If it does not match |
| --- | --- | --- |
| SNI, from the handshake | before the seal is open | the handshake fails, no HTTP status |
| `Host` header, from the request | after the seal is open | `404`, but the connection is fine |

`--resolve starfleet.example.com:8443:127.0.0.1` tells curl to connect to your port forward while still using `starfleet.example.com` as the name. So both the SNI and the `Host` header are right. A plain `https://127.0.0.1:8443` sends no usable name, and the handshake fails with curl exit code `35`.

## Prove which certificate answered

A `200` proves the path works. It does not prove *which* certificate the gate showed, and that matters as soon as a gate serves more than one host. You can ask both sides: the client, and the gateway itself.

### From the client's side

`curl -v` prints the certificate the gateway showed during the handshake:

```sh
https_status -v 2>&1 | grep -E "subject:|issuer:"
```

```text
*  subject: O=Starfleet; CN=starfleet.example.com
*  issuer: O=Starfleet Command; CN=starfleet-ca
```

The exact layout of these lines depends on your curl version.

The subject is the name you gave the server certificate, and the issuer is your CA. So the gate showed exactly the certificate from `starfleet-credential`.

### Without trust, no signal

Now send the same signal without `--cacert`, so curl falls back to the public CAs it knows:

```sh
curl -s -o /dev/null --resolve starfleet.example.com:8443:127.0.0.1 \
  https://starfleet.example.com:8443/productpage; echo "exit=$?"
```

```text
exit=60
```

Exit code `60` means "the certificate is not trusted". The gateway did nothing wrong: curl did not know your CA. A real browser behaves the same way with a certificate from an unknown CA. That is why a public site uses a certificate from a public CA.

### From the gateway's side

`istioctl proxy-config secret` lists the certificates the gateway's Envoy really holds:

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress
```

```text
RESOURCE NAME                         TYPE           STATUS     VALID CERT     SERIAL NUMBER                        NOT AFTER                NOT BEFORE
kubernetes://starfleet-credential     Cert Chain     ACTIVE     true           00000000000000000000000000000001     2027-10-09T09:26:12Z     2026-10-09T09:26:12Z
default                               Cert Chain     ACTIVE     true           cd9f733cc187f798b625d29f662422ef     2026-10-10T09:25:24Z     2026-10-09T09:23:24Z
ROOTCA                                CA             ACTIVE     true           b6675b08fb0a7611a0824cb0029d824d     2036-10-06T09:25:12Z     2026-10-09T09:25:12Z
```

The row `kubernetes://starfleet-credential` with state `ACTIVE` means `istiod` delivered the Secret and the gate is using it. Its serial number is `1`, the `-set_serial 1` you gave `openssl`. The other rows are the gateway's own mesh identity, which it uses for mTLS towards the bridge.

> [!TIP]
> When an HTTPS task fails, run `istioctl proxy-config secret` on the gateway first. If your Secret is missing there, or not `ACTIVE`, the problem is the Secret, not the `Gateway` or the `VirtualService`.

## Common pitfalls

> [!WARNING]
> - **Testing with an IP address.** `https://127.0.0.1:8443` sends no usable SNI, so no server matches and the handshake fails. Use `--resolve` with the real host name.
> - **Mixing up the two checks.** A failed handshake is about the SNI or the certificate. A `404` on a working connection is about the `VirtualService`.
> - **Using `-k` to "fix" a trust error.** `-k` skips the check you want to pass. Give curl the CA with `--cacert` instead.
> - **Forgetting `gateways:` in the `VirtualService`.** Without it the flight plan applies only inside the mesh, and the gate answers `404`.

> *SNI picks the door and its certificate before the seal is open; the `Host` header picks the route after.*
