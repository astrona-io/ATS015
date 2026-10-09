# Terminate TLS At The Ingress Gateway

Inside the mesh, Istio encrypts every request for you. `istiod`, Istio's control plane, gives every workload its own certificate. Both ends of a connection then check each other's certificate: this is mutual TLS, or mTLS. Requests from outside the cluster are different.

A browser or a partner system sends its request to the **ingress gateway**: an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. The client expects HTTPS. It checks the gateway's certificate against a certificate authority it already trusts, so the gateway must show a certificate **you** supply, not one the mesh made.

**TLS** (Transport Layer Security) is the protocol that encrypts a connection, so only the intended receiver can read it. When the gateway **terminates TLS**, it holds the certificate, decrypts the request, and sends it on inside the mesh. The configuration for this is short. What makes it fail, for almost everyone the first time, is one namespace: the gateway reads its certificate from a Secret in **its own** namespace, not in the namespace where the `Gateway` object lives.

This matters because almost every service that users reach over the internet enters the mesh through a gateway like this one. The exam asks you to set it up by hand, under time pressure, and to prove it works. Most failures here give no error message at all: Kubernetes accepts the objects, and the handshake simply fails. If you know where the certificate must live and how to read a failed handshake, a long search becomes a two-minute fix.

This module builds an HTTPS entrance for the `bridge` web frontend in four parts. **Create A TLS Certificate And Secret** makes a certificate authority and a server certificate, and puts them in a Secret where the gateway looks. **Configure An HTTPS Gateway Server** writes the `SIMPLE` TLS server and the `VirtualService`, and proves which certificate the gateway showed. **Redirect HTTP And Rotate The Certificate** sends plain HTTP clients to HTTPS and replaces a certificate with no restart; it ends with the first graded lab. **Troubleshoot A Failed TLS Handshake** breaks the setup on purpose and shows how curl's exit codes point at the cause; it ends with a troubleshooting lab.

## Learning objectives

After this module you can:

- Make a small certificate authority and a server certificate with `openssl`, and say what the SAN (subject alternative name) is for.
- Store a certificate as a Kubernetes TLS Secret in the namespace the gateway pod runs in, and explain why that namespace.
- Write a `Gateway` with a `SIMPLE` TLS server that names the Secret with `credentialName`, and link a `VirtualService` to it.
- Test HTTPS with `curl --resolve` and `--cacert`, and prove which certificate the gateway showed.
- Redirect plain HTTP to HTTPS with `tls.httpsRedirect`, and replace a certificate without restarting the gateway.
- Find the cause of a failed handshake from curl's exit code, `istioctl proxy-config secret` and `istioctl analyze`.

## Before you start

You need Kubernetes basics: namespaces, Secrets, Services and `kubectl`. You also need a rough picture of the ingress gateway. A `Gateway` opens a port on the ingress gateway for some host names. A `VirtualService` with a `gateways:` field says where the requests that come through go next.

Your playground is one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The sample app runs in the namespace **`starfleet`**:

| Workload | What it does |
| --- | --- |
| `bridge` | The web frontend, on `/productpage`, port `9080`. It is the Service you put behind HTTPS |
| `cargo`, `navcom`, `scout` v1-v3 | The backends that `bridge` calls to build its page |
| `shuttle` | Your client pod inside the mesh |

The ingress gateway runs in its own namespace, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. No certificate, no TLS Secret, no `Gateway` and no `VirtualService` exist yet, because you make them in this module.

A `kind` cluster has no cloud load balancer. Instead, `astrona run` keeps two port forwards running: `127.0.0.1:8080` goes to the gateway's port `80`, and `127.0.0.1:8443` goes to its port `443`. You can check them with `astrona port-forward list`. You also need `istioctl` 1.30.5 and `openssl` on your own machine.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

Work in one folder for the whole module, because the certificates you make go into `certs/` there. Then paste the helper below into each new terminal, in that folder. It sends one HTTPS request to `bridge` through the gateway, trusts your test certificate authority, and prints the status code and curl's exit code:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

The helper passes on any `curl` options you add, for example `https_status -v`. It only works once the certificates exist, and you make those in the first part.
