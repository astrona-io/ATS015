# Require Client Certificates At The Edge

Requests from outside the cluster reach your workloads through the **ingress gateway**. The ingress gateway is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. With normal HTTPS, the gateway shows its own certificate to every client, and accepts any client that trusts it. That is right for a public website.

It is wrong for a partner system. Think of a supply company whose servers call your APIs. The list of callers is short and known in advance, and nobody else should even get to connect. For that, the gateway must check the **client's** certificate too. Istio calls this `MUTUAL` TLS at the gateway. TLS (Transport Layer Security) is the protocol that encrypts a connection and lets each side prove who it is with a certificate.

The change in the `Gateway` is one word. The change in the secret is one extra key. And when the gateway refuses a client, the client does not get an HTTP error at all, so you need to know what to look for.

## Learning objectives

After this module you can:

- Explain what a certificate authority (CA) is, and what it means when it signs a certificate.
- Make a CA, a server certificate and a client certificate with `openssl`.
- Build a secret with the keys `tls.crt`, `tls.key` and `ca.crt`, and say why `kubectl create secret tls` cannot build it.
- Configure a `Gateway` server with `tls.mode: MUTUAL` and `credentialName`.
- Say what a client sees when it has no certificate, or a certificate from another CA, and why there is no HTTP status code.
- Prove from the gateway's own proxy that client certificates are checked: the CA in `istioctl proxy-config secret`, and `requireClientCertificate` on the listener.
- Use the second secret layout, with the CA in a separate secret that ends in `-cacert`.
- Say what a checked client certificate proves, and what it does not prove.

## Before you start

Check three things before the first part: the knowledge this module expects, what is in your playground, and one small helper.

### What you should already know

- **The ingress gateway.** A `Gateway` opens a port on the gateway pods for some host names. A `VirtualService` linked to it with `gateways:` says where the requests go next.
- **HTTPS at the gateway with `SIMPLE` TLS.** The gateway shows a server certificate that it reads from a secret named in `credentialName`. That secret must live in the namespace of the gateway **pod**, not in the namespace of the `Gateway` object. The gateway picks the server by the host name the client sends in its first TLS message, called SNI (Server Name Indication).
- **Kubernetes basics.** Namespaces, Secrets, Services and `kubectl logs`.

### What is in your playground

Your playground is one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The sample app runs in the namespace **`starfleet`**:

| Workload | Its role |
| --- | --- |
| `bridge` | The web frontend, on port `9080`. It is the workload you put behind the gateway |
| `cargo`, `navcom`, `scout` v1, v2, v3 | The backends. The `bridge` calls them to build its page |
| `shuttle` | Your test client inside the mesh |

The ingress gateway runs in its own namespace, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. Access logs are on. There is **no** certificate, **no** secret, **no** `Gateway` and **no** `VirtualService` yet: you make them in this module.

The Starfleet is the Istio docs' Bookinfo sample with space names. The paths built into the images keep their old names, so the `bridge` answers on `/productpage`.

A `kind` cluster has no cloud load balancer. `astrona run` keeps two port forwards running for you:

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` |

Check them with `astrona port-forward list`. A refused handshake ends the `8443` forward, and astrona starts it again within about ten seconds. A request sent in that gap gets `000` and curl exit code `7`.

You make the certificates yourself, with `openssl` on your own machine. Work in one folder for the whole module, because every command uses the relative path `certs/`. You also need `istioctl` 1.30.5 on your own machine.

Start your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### One helper to paste first

Paste this into each new terminal, in your working folder. It sends one HTTPS request through the gateway to the `bridge`, trusts your own CA, and prints the HTTP status code and curl's exit code. Any curl options you add, such as a client certificate, are passed on:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

`--resolve` sends the real host name, `starfleet.example.com`, to your local port. The gateway needs that name to pick the right server. The certificate files it uses are made in the first part.

## The parts, in order

1. [Create A CA And Certificates With OpenSSL](./course-01-issue-the-fleet-badges.md): what a CA is, and making the CA, the server certificate and the client certificate.
2. [Configure A MUTUAL TLS Gateway](./course-02-make-the-gate-ask-for-a-badge.md): the three-key secret, the `MUTUAL` gateway, and the first test with and without a client certificate.
3. [Reject Untrusted Client Certificates And Prove It](./course-03-turn-away-strangers-and-prove-it.md): a client certificate from another CA, and reading the proof from the gateway's proxy.
4. [The Separate CA Secret And What A Client Certificate Proves](./course-04-two-secret-layouts-and-what-a-badge-proves.md): the separate `-cacert` secret, and what to do after the certificate check.
5. [Wrap-Up](./course-05-wrap-up.md): a recap, the labs, and cleaning up.

## Why this matters

Partner and machine-to-machine APIs often need more than a password. With `MUTUAL` TLS, a caller without the right client certificate cannot even send a request, so nothing behind the gateway spends any effort on it. The exam asks you to set this up by hand and prove it works. The proof is the hard part, because a refused client gets no status code, and one working request on its own does not show that the certificate check is on.
