# Configure A Passthrough Gateway

The backend `tls-backend` holds its own certificate and ends TLS (Transport Layer Security) itself. To reach it from outside the cluster, the ingress gateway must forward its encrypted traffic without decrypting it. The ingress gateway is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster.

You need two objects for this. A `Gateway` server opens a port and promises not to decrypt. A `VirtualService` routes on the SNI (Server Name Indication) name, the host name the client sends in the open at the start of the connection. Both look a little different from an HTTPS setup that ends TLS at the gateway, and each difference follows from one fact: the gateway cannot read the stream.

## The gateway before you start

Before you change anything, see what a client gets today when it asks for `tls-backend` through the gateway. That gives you a clear "before" to compare with.

<!-- astrona:playground:renew -->

Send one HTTPS request with the SNI name `vault.starfleet.example.com`:

```sh
tls_status vault.starfleet.example.com
```

```text
000
```

`000` means `curl` got no response at all. The gateway is healthy, but no `Gateway` has asked it to listen on port `443` yet. So the gateway drops the connection before the handshake can finish. For the same reason, `astrona port-forward list` shows the `ingress-https` forward as `NotReady` until a server on port `443` exists.

After a failed request like this one, the `8443` port forward drops and restarts itself. For a few seconds the next request fails too, even when the setup is right. Wait about ten seconds between tries whenever a request has just failed.

## The `Gateway`: a server that will not decrypt

The first object to fix that is the `Gateway`. It tells the gateway pod which port to open, for which host names, and what to do with TLS. Save this as `gateway-vault.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: vault-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
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
kubectl apply -f gateway-vault.yaml
```

```text
gateway.networking.istio.io/vault-gateway created
```

Compared with an HTTPS server that ends TLS at the gateway, three fields change, and each one has a reason.

The protocol is `TLS`, not `HTTPS`. `HTTPS` means "end TLS here, then read the HTTP inside". `TLS` means "this is an encrypted stream", with no promise about what is inside. We tried `protocol: HTTPS` with `mode: PASSTHROUGH` on Istio 1.30.5: the mode won, and the gateway still passed the traffic through. But the object then says the opposite of what happens, so always write `TLS` for a passthrough server.

The port name is `tls`. Istio uses the start of a port name as a hint about the protocol, so keep the name in line with the protocol.

There is no `credentialName`. That field names the gateway's own certificate and private key, stored in a Kubernetes Secret. In passthrough the gateway shows no certificate, so it needs none. If you feel you need a secret here, you have drifted back to termination. The `hosts` field, on the other hand, works as before: the gateway picks the server by the SNI name, and that never needed a key.

## The `VirtualService`: a `tls` block

The `Gateway` only opens the port. The `VirtualService` holds the routing rules: it says where traffic for the host of `tls-backend` goes next. A `VirtualService` has three routing sections, and which one works depends on what the proxy can read:

| Section | Matches on | Use it when |
| --- | --- | --- |
| `http` | `uri`, `headers`, `method`, `queryParams` and more | the gateway ended TLS, or the traffic is plain HTTP |
| `tls` | `sniHosts`, `port` | passthrough: the SNI name is all there is |
| `tcp` | `port` and the source | a plain stream with no SNI at all |

For passthrough, the rule goes in a `tls` block. Save this as `virtualservice-tls-backend.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tls-backend
  namespace: starfleet
spec:
  hosts:
  - vault.starfleet.example.com
  gateways:
  - vault-gateway
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

Apply it:

```sh
kubectl apply -f virtualservice-tls-backend.yaml
```

```text
virtualservice.networking.istio.io/tls-backend created
```

Read it like this: *an encrypted connection that arrives at `vault-gateway` on port `443` with the SNI name `vault.starfleet.example.com` goes to the `tls-backend` Service on port `8443`.*

Two details in this rule matter. First, `sniHosts` names the same host as the `Gateway`'s `hosts`. Both read the same value out of the same ClientHello, the first message of the TLS handshake, so one wrong letter leaves the connection with nowhere to go. Second, the destination port is the TLS port of `tls-backend`, `8443`. The gateway opens a connection to it and joins the two streams. It does not make an HTTP request, so there is no plain-text port to aim at.

## The request that now gets through

With both objects in place, test again. `istiod`, Istio's control plane, needs a moment to push the new configuration to the gateway, and the port forward may still be restarting. Wait about a minute, then send the same request as before and also ask for the full response:

```sh
tls_status vault.starfleet.example.com
curl -sk --resolve vault.starfleet.example.com:8443:127.0.0.1 https://vault.starfleet.example.com:8443/
```

```text
200
vault ended TLS itself
```

The `200` and the response came from nginx inside `tls-backend`. Your `curl` and that nginx agreed on the key between them. The gateway moved bytes from one connection to the other without being able to read them.

`--resolve` matters more here than anywhere else. It makes `curl` send `vault.starfleet.example.com` as SNI while it connects to `127.0.0.1`. Without it, the gateway has no host name to route on.

You now have a working passthrough setup. `protocol: TLS`, `mode: PASSTHROUGH` and a `tls` block that matches `sniHosts` belong together: the gateway routes on the SNI name and never decrypts the stream. But a `200` alone does not show that the gateway left the stream alone. Proving where TLS really ended takes a closer look.

## Common pitfalls

> [!WARNING]
> - **Writing `protocol: HTTPS` with `mode: PASSTHROUGH`.** Istio 1.30.5 still passes the traffic through, but the object then claims the gateway reads HTTP. Use `protocol: TLS`.
> - **Adding a `credentialName`.** A passthrough server shows no certificate of its own, so it needs no Secret.
> - **Writing an `http` block.** A passthrough host needs a `tls` block that matches on `sniHosts`.
> - **Aiming at a plain-text port.** The destination must be the port where the backend ends TLS itself.
> - **Testing by IP address.** Without `--resolve` or a real DNS name, no SNI name is sent, and the rule has nothing to match.
