# TLS Passthrough Instead Of Termination

Most of the time, the ingress gateway decrypts every encrypted request that comes in. The ingress gateway is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. It holds its own certificate, ends the TLS session, reads the request inside and then sends it on. That is called **TLS termination**. TLS (Transport Layer Security) is the protocol that encrypts a connection so nobody on the path can read it.

Sometimes the gateway must not decrypt the traffic at all. A backend may need to prove its own identity to the client, with its own certificate. A rule may say that nothing in the middle may ever see the plain contents. Or the backend may check the client's certificate itself. In all these cases the gateway has to **forward the encrypted stream unchanged**, so only the backend can decrypt it. That is **TLS passthrough**, and in Istio it is one setting on the `Gateway`: `mode: PASSTHROUGH`.

Passthrough has a price. The gateway cannot read a path or a header any more, so it can only route on the one value it can still see: the host name the client sends in the open at the start of the connection. That value is called **SNI** (Server Name Indication). Most hosts at the edge are better off with termination, but the exam expects you to set up passthrough by hand, quickly, and to prove it. The setup is short. The hard part is knowing that the routing block changes from `http` to `tls`, and that a wrong setup gives no helpful error. It just drops the connection.

This module covers passthrough in five parts. **What A Proxy Can See** starts with the first message of a TLS handshake: why SNI is readable when nothing else is, and the certificate that the backend `tls-backend` makes for itself. **Configure A Passthrough Gateway** writes the `Gateway` server with `protocol: TLS` and `mode: PASSTHROUGH`, and the `VirtualService` `tls` block that routes on SNI. **Prove Where TLS Ends** collects the evidence: the certificate the client gets, the gateway's listener and the HTTP route that is missing on purpose. **Troubleshoot A Passthrough Setup** breaks the setup three ways, so you can tell the failures apart. **Termination And Passthrough On One Gateway** puts one host the gateway decrypts next to one it passes through, shows what passthrough costs, and gives you one question for choosing a mode.

## Learning objectives

After this module you can:

- Say which parts of a TLS connection a proxy can read without the key, and which it cannot.
- Explain what SNI is and why it is the only thing a passthrough gateway can route on.
- Write a `Gateway` server with `protocol: TLS` and `tls.mode: PASSTHROUGH`, with no `credentialName`.
- Route passthrough traffic with a `VirtualService` `tls` block that matches on `sniHosts`.
- Prove which workload ended TLS, from the certificate the client gets and from the gateway's own listeners and routes.
- Recognise the failures of a wrong passthrough setup: an `http` block, a host mismatch, or no SNI at all.
- Serve one host with termination and another with passthrough on the same gateway, and choose the right mode for a requirement.

## Before you start

You need some knowledge of the ingress gateway. A `Gateway` opens a port on the ingress gateway pods it selects by label. A `VirtualService` holds routing rules, and with `gateways:` it tells the gateway where each request for a host goes next. You have probably seen mostly `http` rules, which match on paths and headers. You also need to know that a certificate carries a name (the subject) and the signature of whoever issued it (the issuer), and that whoever shows it to a client must also hold its private key. Finally, you need Kubernetes basics: namespaces, Deployments, Services, `kubectl logs` and `kubectl exec`.

Your playground is one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The sample app runs in the namespace **`starfleet`**:

| Workload | Its role here |
| --- | --- |
| `bridge` | The web frontend, on port `9080`, path `/productpage`. It is already behind the gateway over plain HTTP |
| `cargo`, `navcom`, `scout` v1, v2, v3 | The backends that `bridge` calls to build its page |
| `shuttle` | Your client inside the mesh |
| `tls-backend` | **The TLS backend.** Not part of the sample app: a small nginx that makes its **own** certificate when it starts and serves HTTPS itself on port `8443` |

The certificate of `tls-backend` says `CN=vault.starfleet.example.com` and `O=vault`. No Kubernetes Secret and no Istio object made it. So if a client sees that certificate, `tls-backend` itself answered.

The gateway runs in its own namespace, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. A `Gateway` named `starfleet-gateway` already lets plain HTTP requests for `starfleet.example.com` reach `bridge`. Access logs are on, so the gateway writes one line for every request or connection. There is **no** passthrough `Gateway` and **no** TLS secret yet: you write them in this module.

A `kind` cluster has no cloud load balancer. `astrona run` keeps two port forwards running: `127.0.0.1:8080` goes to the gateway's port `80`, and `127.0.0.1:8443` goes to its port `443`. Check them with `astrona port-forward list`. You also need `istioctl` 1.30.5 and `openssl` on your own machine.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Two helpers for your terminal

Many commands in this module test the gateway the same way, so two small shell helpers save typing. `tls_status` sends one HTTPS request through the gateway with the SNI name you give it, and prints only the status code. `show_certificate` asks the gateway for the certificate it returns for that SNI name, and prints its subject and its fingerprint (a short checksum that is different for every certificate). Paste them into each new terminal:

```sh
tls_status() { curl -sk --resolve "$1:8443:127.0.0.1" -o /dev/null -w "%{http_code}\n" "https://$1:8443${2:-/}"; }
show_certificate() { openssl s_client -connect 127.0.0.1:8443 -servername "$1" </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256; }
```

Use them like this: `tls_status vault.starfleet.example.com`, or `show_certificate vault.starfleet.example.com`. The `--resolve` option makes `curl` send the host name as SNI while it connects to `127.0.0.1`.
