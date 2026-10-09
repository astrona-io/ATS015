# Overview: Terminate TLS At The Ingress Gateway (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio, an ingress gateway and the Starfleet,
and then waits. There is no task, no `astrona submit` and no pass or fail.
Explore, break things, `astrona destroy`, start over.

Here you put the spaceport arrival gate behind HTTPS. Outside signals arrive
sealed with TLS, the gate opens them with a certificate you made, and the
signal flies on to the bridge inside the mesh.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm. `istio-base` and `istiod` (mission
  control) live in `istio-system`.
- The **ingress gateway** on the planet `istio-ingress`. Its Deployment and
  its Service are both called `istio-ingress`, and its pods carry the label
  **`istio=ingress`**. It reads TLS Secrets from **`istio-ingress`**, its own
  namespace.
- Mesh-wide **access logs**. Read the gate's flight log with
  `kubectl logs -n istio-ingress deploy/istio-ingress --tail=1`.
- Namespace **`starfleet`** (the planet you work on), labelled for injection, with:
  - **The Starfleet**: `bridge` (the flagship page, on `/productpage`),
    `cargo`, `navcom` and `scout` v1/v2/v3, all on port `9080`.
  - **`shuttle`**, a client pod inside the mesh.
- **No certificates, no TLS Secret, no `Gateway` and no `VirtualService`.**
  Making them is the point of the module.

You need `istioctl` 1.30.5 and `openssl` on your own machine. Helm does not
install them for you.

### Reaching the gateway

`kind` has no cloud load balancer, so nothing outside the cluster can reach
the gateway on its own. `astrona run` keeps two port forwards running for you.
A port forward is a tunnel from your machine into the cluster. If one drops,
astrona restarts it.

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` |

Check them with `astrona port-forward list`. You do not need to start a
`kubectl port-forward` yourself.

## Make the test certificates

Run these once, on your own machine, in the folder you work in. They make a
certificate authority (`certs/starfleet-ca.crt`) and a server certificate for
`starfleet.example.com` signed by it:

```sh
mkdir -p certs
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=Starfleet Command/CN=starfleet-ca' \
  -keyout certs/starfleet-ca.key -out certs/starfleet-ca.crt
openssl req -newkey rsa:2048 -nodes -keyout certs/starfleet.example.com.key \
  -subj '/O=Starfleet/CN=starfleet.example.com' -out certs/starfleet.example.com.csr
printf "subjectAltName=DNS:starfleet.example.com\n" > certs/san.ext
openssl x509 -req -sha256 -days 365 -CA certs/starfleet-ca.crt -CAkey certs/starfleet-ca.key \
  -set_serial 1 -in certs/starfleet.example.com.csr -out certs/starfleet.example.com.crt \
  -extfile certs/san.ext
```

## Helper

Paste this into each new terminal, in the same folder. It sends one HTTPS
signal to the bridge through the gateway, trusts your test CA, and prints the
status code and curl's exit code:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

`200 exit=0` means it worked. When TLS fails there is no HTTP status (`000`),
so read the exit code instead:

| curl exit code | Meaning |
| --- | --- |
| `0` | ok |
| `7` | curl cannot connect at all (check the port forward; after a failed handshake it restarts for a few seconds) |
| `35` | the gate cut the TLS handshake: no certificate for this host, or a wrong host name (`istioctl proxy-config secret` tells them apart) |
| `60` | the certificate is not trusted |

## Things to try

Each idea below is a small change to the files you made while reading the
module (`gateway-starfleet.yaml` and `virtualservice-bridge.yaml`). Edit your
saved file, apply it with `kubectl apply -f`, and watch what happens.

- Create the Secret in `starfleet` instead of `istio-ingress`. The `Gateway`
  is accepted, after a few seconds `https_status` fails with `exit=35`, `istioctl proxy-config secret` shows the
  Secret as `WARMING`, and `istioctl analyze -n starfleet` reports `IST0101`.
- Ask for a host the `Gateway` does not serve, such as `other.example.com`,
  with `-k`. The handshake still fails with `exit=35`.
- Leave out `--cacert`. curl refuses the certificate with `exit=60`.
- Serve two host names from one `Gateway`, each with its own certificate, and
  check with `curl -v` which certificate each name gets.
- Replace the Secret with a new certificate and watch the gateway serve it
  without a restart.
- Add `minProtocolVersion: TLSV1_3` to the `tls` block, then force an older
  version with `https_status --tls-max 1.2`. The handshake fails with
  `exit=35`.
- Compare `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress`
  before and after each change.

For an exam-style task with a checked solution, see
[practice.md](./practice.md).

## Start over without a new cluster

```sh
kubectl delete gateways.networking.istio.io,virtualservice --all -n starfleet
kubectl delete secret -n istio-ingress starfleet-credential starfleet-tls --ignore-not-found
kubectl delete secret -n starfleet starfleet-credential-app-ns --ignore-not-found
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-040-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-040-01`.
- `https_status` prints `exit=7`: check the port forwards with
  `astrona port-forward list`, and restart them with
  `astrona port-forward start --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/playground`
  (the same `--git` and `-c` you gave `astrona run`). Right after a failed
  handshake, `exit=7` for a few seconds is normal: astrona is restarting the
  forward.

## When you're done

```sh
astrona destroy ats-015-playground-040-01
rm -r certs
```

(`astrona destroy` takes the environment name, not the configuration path.)
