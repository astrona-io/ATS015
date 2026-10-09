# TLS Passthrough Instead Of Termination

Astronaut, so far the arrival gate (the ingress gateway) opened every sealed signal that came in. It held its own certificate, ended the TLS session, read the request inside and then sent it on. That is called **TLS termination**. TLS (Transport Layer Security) is the lock that seals a signal so nobody on the way can read it.

Sometimes the gate must not open the signal at all. A ship may need to prove its own identity to the visitor, with its own certificate. A rule may say that nothing in the middle may ever see the plain contents. Or the ship may check the visitor's own client certificate itself. In all these cases the gate has to **pass the sealed signal through unopened**, so only the ship it is addressed to can open it. That is **TLS passthrough**, and in Istio it is one setting on the `Gateway`: `mode: PASSTHROUGH`.

Passthrough has a price. The gate cannot read a path or a header any more, so it can only route on the one thing it can still see: the address written on the outside of the envelope. That address is called **SNI** (Server Name Indication). This module shows how to set it up, how to prove it works, how it fails, and what you give up.

## Learning objectives

After this module you can:

- Say which parts of a TLS connection a proxy can read without the key, and which it cannot.
- Explain what SNI is and why it is the only thing a passthrough gate can route on.
- Write a `Gateway` server with `protocol: TLS` and `tls.mode: PASSTHROUGH`, with no `credentialName`.
- Route passthrough traffic with a `VirtualService` `tls` block that matches on `sniHosts`.
- Prove which ship ended TLS, from the certificate the client gets and from the gateway's own listeners and routes.
- Recognise the failures of a wrong passthrough setup: an `http` block, a host mismatch, or no SNI at all.
- Serve one host with termination and another with passthrough on the same gate, and choose the right mode for a requirement.

## Before you start

Every mission starts with a pre-flight check. Make sure you have the knowledge this module expects, know what is waiting in your playground, and have two small helpers ready in your terminal.

### What you should already know

- **The arrival gate.** A `Gateway` opens a port on the ingress gateway pods it selects by label. A `VirtualService` with `gateways:` tells the gate where each signal for a host goes next.
- **The flight plan.** A `VirtualService` holds routing rules. You have mostly seen `http` rules, which match on paths and headers.
- **A certificate.** A certificate is a ship's badge card: it carries a name (the subject) and a seal (the issuer). Whoever shows it to a visitor must also hold its private key.
- **Kubernetes basics.** Namespaces, Deployments, Services, `kubectl logs` and `kubectl exec`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The fleet lives on the planet (namespace) **`starfleet`**:

| Ship | Its role here |
| --- | --- |
| `bridge` | The **flagship**: the web page astronauts see, on port `9080`, path `/productpage`. It is already behind the gate over plain HTTP |
| `cargo`, `navcom`, `scout` v1, v2, v3 | The rest of the fleet. The bridge asks them for its page |
| `shuttle` | Your client inside the mesh |
| `tls-backend` | **The vault.** Not part of the fleet: a small nginx ship that makes its **own** certificate when it starts and serves HTTPS itself on port `8443` |

The vault's certificate says `CN=vault.starfleet.example.com` and `O=vault`. No Kubernetes Secret and no Istio object made it. So if a visitor sees that certificate, the vault itself answered.

The gate lives on its own planet, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. A `Gateway` named `starfleet-gateway` already lets plain HTTP signals for `starfleet.example.com` reach the bridge. Flight logs (access logs) are on, so the gate writes one line for every signal. There is **no** passthrough `Gateway` and **no** TLS secret yet: writing them is your mission.

A `kind` cluster has no cloud load balancer. `astrona run` keeps two port forwards running: `127.0.0.1:8080` goes to the gate's port `80`, and `127.0.0.1:8443` goes to its port `443`. Check them with `astrona port-forward list`. You also need `istioctl` 1.30.5 and `openssl` on your own machine.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### Two helpers to paste first

Paste these into each new terminal. `tls_status` sends one HTTPS signal through the gate with the SNI name you give it, and prints only the status code. `show_certificate` asks the gate for the certificate it hands out for that SNI name, and prints its subject and its fingerprint (a short checksum that is different for every certificate):

```sh
tls_status() { curl -sk --resolve "$1:8443:127.0.0.1" -o /dev/null -w "%{http_code}\n" "https://$1:8443${2:-/}"; }
show_certificate() { openssl s_client -connect 127.0.0.1:8443 -servername "$1" </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256; }
```

Use them like this: `tls_status vault.starfleet.example.com`, or `show_certificate vault.starfleet.example.com`. The `--resolve` option makes `curl` send the host name as SNI while it connects to `127.0.0.1`.

## How this module is organised

1. **[What A Proxy Can See](./course-01-what-a-proxy-can-see.md)**: the first message of a TLS handshake, why SNI is readable when nothing else is, and the vault's own certificate.
2. **[Open A Gate That Does Not Decrypt](./course-02-open-a-gate-that-does-not-decrypt.md)**: the `Gateway` server with `protocol: TLS` and `mode: PASSTHROUGH`, and the `VirtualService` `tls` block.
3. **[Prove Who Opened The Envelope](./course-03-prove-who-opened-the-envelope.md)**: the certificate, the gate's listener and the missing HTTP route. Then your first mission.
4. **[When The Stream Has Nowhere To Go](./course-04-when-the-stream-has-nowhere-to-go.md)**: an `http` block, a wrong host, no SNI. Then a repair mission.
5. **[One Gate, Two Modes](./course-05-one-gate-two-modes.md)**: one host the gate opens and one it passes through, what passthrough costs, and how to choose.
6. **[Wrap-Up](./course-06-wrap-up.md)**: what you learned, your missions, check yourself, and cleaning up.

## Why this matters

Most hosts at the edge should be ended at the gate, because that gives you routing, retries, flight logs and one place to manage certificates. But some ships must keep their own lock and key, and the exam expects you to set that up by hand, quickly, and to prove it. The setup is short. The hard part is knowing that the routing block changes from `http` to `tls`, and that a wrong setup does not give a helpful error. It just drops the connection.
