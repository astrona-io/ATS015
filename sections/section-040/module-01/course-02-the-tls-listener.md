# Part 2 — The TLS listener

> Prerequisite: [Part 1 — How a gateway gets its certificate](./course-01-how-a-gateway-gets-its-certificate.md). Next: [Part 3 — Verifying, redirecting and rotating](./course-03-verifying-redirecting-and-rotating.md).

The credential is waiting in `istio-system`. This part writes the listener that asks for it — a `servers` entry whose four significant fields each change behaviour, including one that looks like documentation and is not.

## The server block

```yaml
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - booking.ica.local
      tls:
        mode: SIMPLE
        credentialName: booking-credential
```

- **`mode: SIMPLE`** is ordinary server-side TLS: the gateway presents a certificate, the client is not authenticated. (`MUTUAL` is [Module 2](../module-02/course.md), `PASSTHROUGH` is [Module 3](../module-03/course.md).)
- **`credentialName`** — [Part 1](./course-01-how-a-gateway-gets-its-certificate.md)'s bare name, resolved in the gateway pod's namespace.
- **`protocol: HTTPS`** tells Istio to terminate TLS *and* treat what is inside as HTTP.
- **`name: https`** is not a comment.

That last one deserves its own explanation, because "the name is just a label" is a reasonable assumption everywhere else in Kubernetes.

## The port name changes behaviour

Istio derives protocol handling partly from the port's **name prefix**. A port named `https`, `https-public` or `https2` is handled as HTTPS; one named `web`, `tls-port` or `secure` is not, or is handled as something else entirely.

The convention is `<protocol>[-<suffix>]`, and the recognised prefixes are `http`, `http2`, `https`, `grpc`, `tcp`, `tls`, `mongo`, `redis` and a few more. A name Istio does not recognise falls back to plain TCP, which means the listener comes up, bytes flow, and none of the HTTP-level features — routing on paths, header rules, L7 telemetry — work. The symptom is a `Gateway` that applies cleanly and a `VirtualService` whose `http` rules never match.

The same naming rule applies to `Service` ports throughout a mesh, which is why an unnamed or oddly named Service port is a recurring cause of "Istio is not routing this". It is one convention, applied in two places.

For this module: `protocol: HTTPS` on port `443` with a name starting `https`. Getting either of the last two wrong produces a listener that is not what you asked for.

## How `hosts` and SNI select a listener

A single gateway usually serves several hostnames, each with its own certificate. Something has to decide which one answers a given connection, and — before any HTTP is available — the only thing to decide on is SNI.

```text
   client connects, ClientHello carries SNI: booking.ica.local
        │
        ▼
   gateway proxy: which filter chain matches this SNI?
        │
        ├── servers[0] hosts: [booking.ica.local]  ──▶ present booking-credential
        ├── servers[1] hosts: [shop.ica.local]     ──▶ present shop-credential
        └── no match                               ──▶ connection fails in the handshake
        │
        ▼
   TLS terminated, HTTP now visible
        │
        ▼
   route selection: which VirtualService, by Host header?
```

Two selections, on two different values, at two different stages — and they are easy to conflate because in normal use both are the same hostname:

| | value used | stage | failure if wrong |
| --- | --- | --- | --- |
| listener selection | **SNI**, from the ClientHello | before decryption | handshake fails, no HTTP status |
| route selection | **`Host` header**, from the request | after decryption | `404`, connection fine |

That table is the reason a test without SNI looks like a certificate problem. Connect to the gateway by IP, or with `-H "Host: …"` alone over HTTPS, and the ClientHello carries no SNI, nothing matches, and the handshake fails — which looks identical to a missing or broken credential. `curl --resolve <host>:<port>:<ip>` is the fix: it makes `curl` connect to a chosen address while still treating the request as being for that hostname, so SNI *and* the `Host` header are both correct.

The `hosts` field also accepts `*` and `*.example.com`. A `*` listener with a certificate for one specific name will happily accept connections it cannot serve correctly, so wildcards are best paired with wildcard certificates.

## Binding a route

A `Gateway` only opens a door. Something has to say where traffic goes once through it, and that is a `VirtualService` naming the gateway in its `gateways` list:

```yaml
spec:
  hosts:
    - booking.ica.local          # matched against the Host header
  gateways:
    - booking-gateway            # same namespace; otherwise <ns>/<name>
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

Without it, the listener comes up, the handshake succeeds, and every request returns `404` — a useful signature in itself, because it tells you TLS is entirely fine and the problem is routing.

> [!TIP]
> **Try it — serve HTTPS at the edge**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: networking.istio.io/v1
> kind: Gateway
> metadata:
>   name: booking-gateway
>   namespace: tls-demo
> spec:
>   selector:
>     istio: ingressgateway
>   servers:
>     - port:
>         number: 443
>         name: https
>         protocol: HTTPS
>       hosts:
>         - booking.ica.local
>       tls:
>         mode: SIMPLE
>         credentialName: booking-credential
> ---
> apiVersion: networking.istio.io/v1
> kind: VirtualService
> metadata:
>   name: booking
>   namespace: tls-demo
> spec:
>   hosts:
>     - booking.ica.local
>   gateways:
>     - booking-gateway
>   http:
>     - match:
>         - uri:
>             prefix: /book
>       route:
>         - destination:
>             host: booking-service
>             port:
>               number: 80
> YAML
>
> kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443 >/dev/null 2>&1 &
> sleep 2
> curl -sk --resolve booking.ica.local:8443:127.0.0.1 \
>   -o /dev/null -w 'https: %{http_code}\n' https://booking.ica.local:8443/book
> ```
>
> Expect something like:
>
> ```text
> https: 200
> ```
>
> The port-forward runs in the background and stays up until you stop it (`kill %1`, or close the shell). `--resolve` is doing the work described above — connecting to localhost while sending `booking.ica.local` as both SNI and `Host`. `-k` accepts the self-signed certificate, which a browser would reject.

Note the `selector: istio: ingressgateway` in the `Gateway`. It picks which gateway *deployment* this configuration is pushed to, by pod label — the same selector mechanism as every security object in this course, pointed at edge proxies instead of application workloads.

> *`protocol` and the port's name prefix both shape how a listener is handled, and SNI selects the listener while the `Host` header selects the route.*

## Reference

- [Gateway reference](https://istio.io/latest/docs/reference/config/networking/gateway/) — `servers`, `port`, `hosts` and the `selector`.
- [Protocol selection](https://istio.io/latest/docs/ops/configuration/traffic-management/protocol-selection/) — the port-name prefixes Istio recognises and what happens without one.
- [Secure gateways task](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/) — the same `Gateway` plus `VirtualService` pairing, with Istio's own testing commands.
