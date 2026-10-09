# TLS Passthrough Instead Of Termination

So far the ingress gateway decrypted every encrypted request that came in. The ingress gateway is an Envoy proxy at the edge of the mesh that accepts traffic from outside the cluster. It held its own certificate, ended the TLS session, read the request inside and then sent it on. That is called **TLS termination**. TLS (Transport Layer Security) is the protocol that encrypts a connection so nobody on the path can read it.

Sometimes the gateway must not decrypt the traffic at all. A backend may need to prove its own identity to the client, with its own certificate. A rule may say that nothing in the middle may ever see the plain contents. Or the backend may check the client's certificate itself. In all these cases the gateway has to **forward the encrypted stream unchanged**, so only the backend can decrypt it. That is **TLS passthrough**, and in Istio it is one setting on the `Gateway`: `mode: PASSTHROUGH`.

Passthrough has a price. The gateway cannot read a path or a header any more, so it can only route on the one value it can still see: the host name the client sends in the open at the start of the connection. That value is called **SNI** (Server Name Indication). This module shows how to set it up, how to prove it works, how it fails, and what you give up.

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

Check three things before the first part: the knowledge this module expects, what is waiting in your playground, and two small helpers in your terminal.

### What you should already know

- **The ingress gateway.** A `Gateway` opens a port on the ingress gateway pods it selects by label. A `VirtualService` with `gateways:` tells the gateway where each request for a host goes next.
- **Routing rules.** A `VirtualService` holds routing rules. You have mostly seen `http` rules, which match on paths and headers.
- **A certificate.** A certificate carries a name (the subject) and the signature of whoever issued it (the issuer). Whoever shows it to a client must also hold its private key.
- **Kubernetes basics.** Namespaces, Deployments, Services, `kubectl logs` and `kubectl exec`.

### What is in your playground

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

### Two helpers to paste first

Paste these into each new terminal. `tls_status` sends one HTTPS request through the gateway with the SNI name you give it, and prints only the status code. `show_certificate` asks the gateway for the certificate it returns for that SNI name, and prints its subject and its fingerprint (a short checksum that is different for every certificate):

```sh
tls_status() { curl -sk --resolve "$1:8443:127.0.0.1" -o /dev/null -w "%{http_code}\n" "https://$1:8443${2:-/}"; }
show_certificate() { openssl s_client -connect 127.0.0.1:8443 -servername "$1" </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256; }
```

Use them like this: `tls_status vault.starfleet.example.com`, or `show_certificate vault.starfleet.example.com`. The `--resolve` option makes `curl` send the host name as SNI while it connects to `127.0.0.1`.

## How this module is organised

1. **[What A Proxy Can See](./course-01-what-a-proxy-can-see.md)**: the first message of a TLS handshake, why SNI is readable when nothing else is, and the certificate of `tls-backend`.
2. **[Configure A Passthrough Gateway](./course-02-open-a-gate-that-does-not-decrypt.md)**: the `Gateway` server with `protocol: TLS` and `mode: PASSTHROUGH`, and the `VirtualService` `tls` block.
3. **[Prove Where TLS Ends](./course-03-prove-who-opened-the-envelope.md)**: the certificate, the gateway's listener and the missing HTTP route. Then your first lab.
4. **[Troubleshoot A Passthrough Setup](./course-04-when-the-stream-has-nowhere-to-go.md)**: an `http` block, a wrong host, no SNI. Then a troubleshooting lab.
5. **[Termination And Passthrough On One Gateway](./course-05-one-gate-two-modes.md)**: one host the gateway decrypts and one it passes through, what passthrough costs, and how to choose.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, the labs, check yourself, and cleaning up.

## Why this matters

Most hosts at the edge should have TLS ended at the gateway, because that gives you routing, retries, access logs and one place to manage certificates. But some backends must keep their own certificate and key, and the exam expects you to set that up by hand, quickly, and to prove it. The setup is short. The hard part is knowing that the routing block changes from `http` to `tls`, and that a wrong setup does not give a helpful error. It just drops the connection.
