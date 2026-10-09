# Overview: Require Client Certificates At The Edge (Playground)

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio, an ingress gateway and the Starfleet,
and then waits. There is no task, no `astrona submit` and no pass or fail.
Explore, break things, `astrona destroy`, start over.

The **ingress gateway** is the spaceport arrival gate: the one door that
signals from outside the solar system come through. In this playground you
make it check the visitor's ID badge (a client certificate) as well as
showing its own.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm. `istio-base` and `istiod` live in
  `istio-system`. `istiod` is mission control: it sends every proxy its orders.
- The **ingress gateway** on the planet `istio-ingress`. Its Deployment and
  its Service are both called `istio-ingress`, and its pods carry the label
  **`istio=ingress`**. A `Gateway` must select that label, and the secret it
  names in `credentialName` must live in `istio-ingress`.
- Mesh-wide **access logs**, so every proxy writes one line per signal.
- Namespace **`starfleet`** (the planet you work on), labelled for injection, with:
  - **The Starfleet**: `bridge` (the flagship page, on `/productpage`),
    `cargo`, `navcom` and `scout` v1, v2 and v3, all on port `9080`.
  - **`shuttle`**, a client pod inside the mesh.
- **No certificate, no secret, no `Gateway` and no `VirtualService`.** Making
  them is the point of the module.

You also need `istioctl` 1.30.5 and `openssl` on your own machine. Helm does
not install them for you.

### Reaching the gateway

`kind` has no cloud load balancer, so nothing outside the cluster can reach
the gateway on its own. `astrona run` keeps two port forwards running for you.
If one drops, for example after a refused TLS handshake, astrona restarts it
within about ten seconds.

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` |

Check them with `astrona port-forward list`. You do not need to start a
`kubectl port-forward` yourself.

## Make the certificates

Work in one folder on your own machine. These commands make a CA
(`example.com`), a server certificate for `starfleet.example.com` and a
client certificate for `client.example.com`, all in `certs/`:

```sh
mkdir -p certs
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=example Inc./CN=example.com' \
  -keyout certs/example.com.key -out certs/example.com.crt
openssl req -out certs/starfleet.example.com.csr -newkey rsa:2048 -nodes \
  -keyout certs/starfleet.example.com.key \
  -subj "/CN=starfleet.example.com/O=starfleet organization"
printf "subjectAltName=DNS:starfleet.example.com\n" > certs/san.ext
openssl x509 -req -sha256 -days 365 -CA certs/example.com.crt -CAkey certs/example.com.key \
  -set_serial 0 -in certs/starfleet.example.com.csr -out certs/starfleet.example.com.crt \
  -extfile certs/san.ext
openssl req -out certs/client.example.com.csr -newkey rsa:2048 -nodes \
  -keyout certs/client.example.com.key \
  -subj "/CN=client.example.com/O=client organization"
openssl x509 -req -sha256 -days 365 -CA certs/example.com.crt -CAkey certs/example.com.key \
  -set_serial 1 -in certs/client.example.com.csr -out certs/client.example.com.crt
```

The module's first part explains each command.

## Helper

Paste this into each new terminal, in the folder that holds `certs/`. It
sends one HTTPS signal through the gate to the bridge, trusts your CA, and
prints the status code and curl's exit code. Any curl options you add are
passed on:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

Use it like this: `https_status`, or
`https_status --cert certs/client.example.com.crt --key certs/client.example.com.key`.

curl's exit codes when TLS fails: `7` cannot connect (also for a few
seconds after a refused handshake, while the port forward restarts), `35` or
`56` the gate said no during TLS (in our runs a missing or refused client
certificate gave `56`, a gate with no usable certificate gave `35`), `60`
the server certificate is not trusted. Wait about ten seconds after a refused
knock before the next one.

## Things to try

Each idea below is a small change to the files you made while reading the
module (`virtualservice-bridge.yaml` and `gateway-starfleet.yaml`). Edit your
saved file, apply it with `kubectl apply -f`, and watch what happens. The
module's parts show the full YAML for every step.

- Switch the same `Gateway` between `SIMPLE` and `MUTUAL` and compare
  `https_status` without a client certificate each time.
- Compare the listener before and after:
  `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress --port 443 -o json | grep requireClientCertificate`.
- Create the secret with `kubectl create secret tls` (no `ca.crt`) and point
  a `MUTUAL` gateway at it. Read `istioctl proxy-config secret deploy/istio-ingress -n istio-ingress`
  and look at the `-cacert` row, then test with a good client certificate.
- Create the secret in `starfleet` instead of `istio-ingress`, then run
  `istioctl analyze -n starfleet`.
- Make a client certificate from another CA (the commands are in the module),
  turn up the gate's connection log with
  `istioctl proxy-config log deploy/istio-ingress -n istio-ingress --level connection:debug`,
  knock with no certificate and with the stranger's, and compare the reasons:
  `kubectl logs -n istio-ingress deploy/istio-ingress --since=1m | grep TLS_error`.
- Put the CA in a separate secret named `<credentialName>-cacert` and check
  that the gate still turns away visitors without a badge.
- Replace `ca.crt` in the secret with the other CA, and watch your own good
  client get turned away while the stranger gets in. No restart is needed:
  mission control sends the new CA to the gate by itself.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete gateways.networking.istio.io,virtualservice --all -n starfleet
kubectl delete secret -n istio-ingress starfleet-credential-mutual starfleet-credential-split starfleet-credential-split-cacert --ignore-not-found
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-040-02`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-040-02`.
- `https_status` prints `exit=7`: check the port forward with
  `astrona port-forward list`, and restart it with `astrona port-forward start -c .`.
- `https_status` prints `exit=77` or a file error: you are not in the folder
  that holds `certs/`.

## When you're done

```sh
astrona destroy ats-015-playground-040-02
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

An exam-style mission for this playground, astronaut. Start the playground
first, make the certificates in `certs/` and paste the `https_status` helper
from the Helper section above. The solution uses both.

Try the task on your own first, then open the solution. The solution was run
and checked on a real cluster. If you worked through the module first, clear
the old objects with the commands under "Start over without a new cluster" above
before you begin.

### Task: badges on 443, a redirect on 80

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
