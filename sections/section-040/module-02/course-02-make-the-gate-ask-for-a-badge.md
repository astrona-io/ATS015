# Make The Gate Ask For A Badge

Astronaut, you have a badge office and two badges. Now you hand the gate what it needs and switch on the badge check. Then you knock on the gate twice: once without a badge, once with one.

`MUTUAL` differs from `SIMPLE` TLS by one word in the `Gateway` and one key in the secret. This part starts with the secret, because that is where most mistakes happen.

The commands below need the files in `certs/` (the CA `example.com`, the server badge `starfleet.example.com` and the client badge `client.example.com`). Run them from the folder that holds `certs/`.

## One secret, two jobs

The gate needs two different things from its secret, and Envoy (the proxy program inside the gateway pod) has a name for each:

| Key in the secret | What it is | Envoy's name for the job |
| --- | --- | --- |
| `tls.crt` | the server badge | what the gate **shows** (`tls_certificate`) |
| `tls.key` | its private key | |
| `ca.crt` | the CA's public certificate | what the gate **checks visitors against** (`validation_context`) |

For `SIMPLE` TLS, only the first two keys exist, and the gate checks nobody. Adding `ca.crt` is what gives the gate something to check visitors' badges against.

The key names are fixed: `tls.crt`, `tls.key` and `ca.crt`. Istio also reads an older set of names, `cert`, `key` and `cacert` (we checked: a secret with only those three keys works the same). Any other name, such as `ca`, is ignored.

### Why `kubectl create secret tls` cannot build it

`kubectl create secret tls` takes exactly one certificate and one key. It has no flag for a CA. So you build this secret with `kubectl create secret generic`, and name each key yourself.

The secret goes to the planet where the gateway **pod** runs, `istio-ingress`. The gate reads `credentialName` from its own namespace and nowhere else.

<!-- astrona:playground:renew -->

### Create the secret

Create it with the three keys:

```sh
kubectl create -n istio-ingress secret generic starfleet-credential-mutual \
  --from-file=tls.key=certs/starfleet.example.com.key \
  --from-file=tls.crt=certs/starfleet.example.com.crt \
  --from-file=ca.crt=certs/example.com.crt
```

```text
secret/starfleet-credential-mutual created
```

The `name=path` form of `--from-file` sets the key name inside the secret, whatever the file is called on disk. Without `tls.crt=`, the key would be named after the file, `starfleet.example.com.crt`, and the gate would not find it.

Then check the key names before you do anything else:

```sh
kubectl get secret starfleet-credential-mutual -n istio-ingress \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

```text
ca.crt
tls.crt
tls.key
```

Exactly three keys, with exactly those names.

## Switch the gate to `MUTUAL`

The secret is in place. Now you need the flight plan for the bridge and a `Gateway` that asks for a badge.

### The flight plan behind the gate

The `VirtualService` is the flight plan: it says where signals that come through the gate go next. TLS is the gate's job, so the flight plan looks the same for HTTP and for HTTPS.

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

### The gate that asks for a badge

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
      mode: MUTUAL
      credentialName: starfleet-credential-mutual
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway created
```

Everything except `tls` is what any HTTPS server on a gate needs: port `443`, protocol `HTTPS`, a port name that starts with `https`, the host, and a selector that matches the gateway pods (`istio: ingress`). The `tls` block has two fields:

- `mode: MUTUAL` makes the gate ask every visitor for a badge, and check it.
- `credentialName` names the secret on the gate's planet, `istio-ingress`.

## What changes in the handshake

The **TLS handshake** is the first greeting, where both sides agree on how to seal the envelope. `MUTUAL` adds one request from the gate, and one check on its side.

```mermaid
sequenceDiagram
    participant V as visitor
    participant G as gate
    V->>G: hello, SNI starfleet.example.com
    G-->>V: server badge
    G-->>V: please show your badge
    V->>G: client badge, or nothing
    Note over G: check the badge with ca.crt
    G-->>V: hang up, or carry on
```

The gate asks for a badge, and the visitor answers with one or without one. The request and the check both happen inside the handshake, before a single byte of HTTP exists. That is why a turned-away visitor never gets an HTTP status code.

### See it in your playground

The commands below use the `https_status` helper from the landing page. If this is a new terminal, paste it first:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

Mission control (`istiod`) needs a moment to send the gate its new orders, so wait about a minute after the apply. Then knock with the visitor's badge first, and without a badge second:

```sh
https_status --cert certs/client.example.com.crt --key certs/client.example.com.key
https_status
```

```text
200 exit=0
000 exit=56
```

With the badge, the bridge answers `200`. Without a badge, curl gets no HTTP status at all (`000`) and exits with code `56`: the connection was cut. The gate did the checking, and in the second case the signal was never sent on to the bridge.

The order matters for one reason. A refused handshake also ends astrona's port forward on `8443`, and astrona needs a few seconds to start it again. A signal sent in that gap gets `000 exit=7`. So after a refused knock, wait about ten seconds before the next one.

curl's exit code tells you what went wrong when there is no status code:

| Exit code | Meaning |
| --- | --- |
| `0` | all fine |
| `7` | curl could not connect at all: the port forward is down, or still restarting after a refused handshake |
| `35` or `56` | the gate said no during TLS: a missing or refused badge, a host name no server matches, or a gate that could not load its own certificates |
| `60` | curl does not trust the gate's own badge |

In our runs, a missing or refused badge gave `56`, and the other TLS failures gave `35`. With TLS 1.3, the visitor finishes its side of the handshake before the gate has checked the badge. The gate then sends a "certificate required" alert and hangs up, and curl only notices when it tries to read the answer. Other curl builds may report it differently, so treat `35` and `56` alike: the gate said no, and the gate's side tells you why.

## Common pitfalls

> [!WARNING]
> - **Using `kubectl create secret tls` for `MUTUAL`.** It cannot carry `ca.crt`, so the gate has nothing to check visitors against. Use `kubectl create secret generic` with `--from-file=ca.crt=...`.
> - **Wrong key names.** The keys must be `tls.crt`, `tls.key` and `ca.crt` (or the older `cert`, `key`, `cacert`). Check them with the `go-template` command before you test.
> - **The secret on the wrong planet.** It belongs in `istio-ingress`, where the gateway pod runs, not in `starfleet`, where the `Gateway` object lives.
> - **Expecting `403` for a missing badge.** The visitor is turned away in the handshake. Look for `000` and curl exit code `56` (or `35`).
> - **Knocking again too fast.** After a refused handshake the port forward restarts, and the next signal gets `000 exit=7` for a few seconds. Wait about ten seconds.
> - **Testing only with a good badge.** A `200` with a badge does not show that the gate checks badges. Always test without one too.

> *`ca.crt` is the one extra key that lets the gate check a visitor's badge, and the check happens before any HTTP is sent.*

## Your mission: Require Client Certificates At The Edge

You can now build the three-key secret and switch a gateway to `MUTUAL`. Now prove it in a graded mission: expose a service over HTTPS so that only clients with a badge from the given CA get in. This mission uses its own small app (`booking-service` in the namespace `mtlsedge-demo`) and the gateway of an `istioctl` install, `istio-ingressgateway` in `istio-system`.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-02
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-040-02
astrona start ats-015-playground-040-02
```
