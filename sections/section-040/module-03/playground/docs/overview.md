# Overview: TLS Passthrough Instead Of Termination (Playground)

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio, the ingress gateway, the Starfleet and
one sealed ship called the vault, and then waits. There is no task, no
`astrona submit` and no pass or fail. Explore, break things, `astrona destroy`,
start over.

In this module the arrival gate learns to pass a sealed signal through
**unopened**. Only the ship it is addressed to can open it.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm. `istio-base` and `istiod` live in
  `istio-system`. `istiod` is mission control: it sends every proxy its orders.
- The **ingress gateway** (the arrival gate) on the planet `istio-ingress`. Its
  Deployment and its Service are both called `istio-ingress`, and its pods
  carry the label **`istio=ingress`**. A `Gateway` must select that label.
- Mesh-wide **access logs**: every proxy writes one line per signal. Read the
  gate's flight log with
  `kubectl logs -n istio-ingress deploy/istio-ingress --tail=1`.
- Namespace **`starfleet`** (the planet you work on), labelled for injection, with:
  - **The Starfleet**: `bridge` (the flagship page, on `/productpage`),
    `cargo`, `navcom` and `scout` v1, v2 and v3, all on port `9080`.
  - **`shuttle`**, a client pod inside the mesh.
  - **`tls-backend`, the vault.** It is not part of the Starfleet. It is a
    small nginx ship that makes its **own** self-signed certificate when it
    starts (`CN=vault.starfleet.example.com`, `O=vault`) and serves HTTPS itself
    on port `8443`. It answers every path with `vault ended TLS itself`.
- **The bridge is already behind the gate over plain HTTP**: a `Gateway`
  named `starfleet-gateway` (port `80`, host `starfleet.example.com`) and a
  `VirtualService` named `bridge`.
- **No passthrough `Gateway`, no TLS secret.** Writing them is the point of the
  module.

You also need `istioctl` 1.30.5 and `openssl` on your own machine. Helm does
not install them for you.

### Reaching the gateway

`kind` has no cloud load balancer, so nothing outside the cluster can reach
the gateway on its own. `astrona run` keeps two port forwards running for you.
A port forward is a tunnel from your machine into the cluster. If one drops,
astrona restarts it.

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the gate, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the gate, port `443` |

Check them with `astrona port-forward list`. You do not need to start a
`kubectl port-forward` yourself.

## Helpers

Paste these into each new terminal. `tls_status` sends one HTTPS signal
through the gate with the SNI name you give it and prints only the status
code. `show_certificate` asks the gate for the certificate it hands out for
that SNI name and prints who it belongs to:

```sh
tls_status() { curl -sk --resolve "$1:8443:127.0.0.1" -o /dev/null -w "%{http_code}\n" "https://$1:8443${2:-/}"; }
show_certificate() { openssl s_client -connect 127.0.0.1:8443 -servername "$1" </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256; }
```

Use them like this: `tls_status vault.starfleet.example.com`,
`tls_status starfleet.example.com /productpage`,
`show_certificate vault.starfleet.example.com`.

## Things to try

The reference YAML is in `examples/` (`01-…`, `02-…`, `03-…`), and each
mistake case is in `examples/cases/`. Copy what you need into your own files
and apply them with `kubectl apply -f`.

- Before any passthrough object exists, run `tls_status vault.starfleet.example.com`
  and note the failure.
- Apply the passthrough `Gateway` and `VirtualService` and compare
  `show_certificate vault.starfleet.example.com` with the certificate the vault
  pod holds on disk.
- Swap the `tls` block for an `http` block (`cases/c1-…`) and watch the
  connection fail while every object reports as applied. The gate's port
  443 listener disappears.
- Make the `Gateway`'s `hosts` disagree with `sniHosts` by one letter
  (`cases/c2-…`). `istioctl analyze -n starfleet` reports `IST0132`.
- Set `protocol: HTTPS` while keeping `mode: PASSTHROUGH` (`cases/c3-…`) and run
  `istioctl analyze -n starfleet`. On Istio 1.30.5 the mode wins: the gate
  still passes the signal through and `analyze` stays quiet. Write `TLS`
  anyway, so the object says what really happens.
- Connect with no SNI at all:
  `openssl s_client -connect 127.0.0.1:8443 -noservername </dev/null`.
- Add an HTTPS server the gate ends itself for `starfleet.example.com`
  (`03-…`) and compare the two certificates the same gate hands out.
- Compare `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress --port 443`
  and `istioctl proxy-config routes deploy/istio-ingress -n istio-ingress`
  before and after each change.
- Compare the gate's flight log for a passthrough signal with one for the
  bridge, and note which fields stay empty.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

This removes the passthrough objects and the gate's own certificate, and
leaves the bridge's HTTP gate alone:

```sh
kubectl delete gateways.networking.istio.io vault-gateway -n starfleet --ignore-not-found
kubectl delete virtualservice tls-backend -n starfleet --ignore-not-found
kubectl delete secret starfleet-credential -n istio-ingress --ignore-not-found
```

If you added an HTTPS server to `starfleet-gateway`, remove that server from
your saved file and apply it again. To get everything back exactly as it
started, destroy the playground and run it again.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-040-03`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-040-03`.
- `tls_status` prints `000` for every host, even the bridge: check the port
  forwards with `astrona port-forward list`. `ingress-https` stays
  `NotReady` until some `Gateway` opens port `443`, and after every failed
  signal it restarts, which takes a few seconds.

## When you're done

```sh
astrona destroy ats-015-playground-040-03
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

An exam-style mission for this playground, astronaut. Start the playground
first, and paste the `tls_status` and `show_certificate` helpers from
the Helpers section above. The solution uses them.

Try the task on your own first, then open the solution.

### Task: one Gateway, one sealed host, one opened host

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
