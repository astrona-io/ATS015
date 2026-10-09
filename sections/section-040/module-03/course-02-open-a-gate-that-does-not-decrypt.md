# Open A Gate That Does Not Decrypt

Astronaut, now you set up the gate so it passes the vault's sealed signals through unopened. You need two objects: a `Gateway` server that does not decrypt, and a `VirtualService` that routes on the address on the envelope. Both look a little different from the HTTPS setup you may know, and each difference follows from one fact: the gate cannot read the stream.

## The gate before you start

First, see what a visitor gets today when it asks for the vault through the gate.

<!-- astrona:playground:renew -->

### Knock on port 443

Send one HTTPS signal with the SNI name `vault.starfleet.example.com`:

```sh
tls_status vault.starfleet.example.com
```

```text
000
```

`000` means `curl` got no reply at all. The gate is healthy, but no `Gateway` has asked it to listen on port `443` yet. So the gate drops the connection before the handshake can finish. For the same reason, `astrona port-forward list` shows the `ingress-https` forward as `NotReady` until a server on port `443` exists.

After a failed signal like this one, the `8443` port forward drops and restarts itself. For a few seconds the next signal fails too, even when the setup is right. Wait about ten seconds between tries whenever a signal has just failed.

## The `Gateway`: a server that will not decrypt

The `Gateway` tells the gate pod which port to open, for which host names, and what to do with TLS. For passthrough, three fields change compared with an HTTPS server that ends TLS at the gate.

### Write the server

Save this as `gateway-vault.yaml`:

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

### Three fields, three reasons

- **`protocol: TLS`, not `HTTPS`.** `HTTPS` means "end TLS here, then read the HTTP inside". `TLS` means "this is a sealed stream", with no promise about what is inside. We tried `protocol: HTTPS` with `mode: PASSTHROUGH` on Istio 1.30.5: the mode won, and the gate still passed the signal through. But the object then says the opposite of what happens, so always write `TLS` for a passthrough server.
- **`name: tls`.** Istio uses the start of a port name as a hint about the protocol. Keep the name in line with the protocol.
- **No `credentialName`.** That field names the gate's own badge and key, kept in the gate's safe (a Kubernetes Secret). In passthrough the gate shows no certificate, so it needs none. If you feel you need a secret here, you have drifted back to termination.

`hosts` still works as before. The gate picks the server by the SNI name, and that never needed a key.

## The `VirtualService`: a `tls` block

The `Gateway` only opens the port. The `VirtualService` (the flight plan) says where a signal for the vault's host flies next. Here the rule sits in a `tls` block, not in an `http` block.

### Three kinds of rules

A `VirtualService` has three routing sections. Which one works depends on what the proxy can read:

| Section | Matches on | Use it when |
| --- | --- | --- |
| `http` | `uri`, `headers`, `method`, `queryParams` and more | the gate ended TLS, or the traffic is plain HTTP |
| `tls` | `sniHosts`, `port` | passthrough: the SNI name is all there is |
| `tcp` | `port` and the source | a plain stream with no SNI at all |

### Write the flight plan

Save this as `virtualservice-tls-backend.yaml`:

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

Read it like this: *a sealed signal that arrives at `vault-gateway` on port `443` with the SNI name `vault.starfleet.example.com` flies to the `tls-backend` Service on port `8443`.*

Two details matter:

- **`sniHosts` names the same host as the `Gateway`'s `hosts`.** Both read the same value out of the same ClientHello. One wrong letter, and the signal has nowhere to go.
- **The destination port is the vault's TLS port, `8443`.** The gate opens a connection to it and joins the two streams. It does not make an HTTP request, so there is no plain-text port to aim at.

### See it in your playground

Mission control needs a moment to radio the new orders to the gate, and the port forward may still be restarting. Wait about a minute, then send the same signal as before and ask for the full reply:

```sh
tls_status vault.starfleet.example.com
curl -sk --resolve vault.starfleet.example.com:8443:127.0.0.1 https://vault.starfleet.example.com:8443/
```

```text
200
vault ended TLS itself
```

The `200` and the reply came from nginx inside the vault. Your `curl` and that nginx agreed on the key between them. The gate moved bytes from one connection to the other without being able to read them.

`--resolve` matters more here than anywhere else. It makes `curl` send `vault.starfleet.example.com` as SNI while it connects to `127.0.0.1`. Without it, the gate has no address to route on.

## Common pitfalls

> [!WARNING]
> - **Writing `protocol: HTTPS` with `mode: PASSTHROUGH`.** Istio 1.30.5 still passes the signal through, but the object then claims the gate reads HTTP. Use `protocol: TLS`.
> - **Adding a `credentialName`.** A passthrough server shows no certificate of its own, so it needs no Secret.
> - **Writing an `http` block.** A passthrough host needs a `tls` block that matches on `sniHosts`.
> - **Aiming at a plain-text port.** The destination must be the port where the ship ends TLS itself.
> - **Testing by IP address.** Without `--resolve` or a real DNS name, no SNI name is sent, and the rule has nothing to match.

> *`protocol: TLS`, `mode: PASSTHROUGH` and a `tls` block that matches `sniHosts` belong together: the gate routes on the address on the envelope and never opens it.*
