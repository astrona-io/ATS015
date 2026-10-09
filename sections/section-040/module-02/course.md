# Require Client Certificates At The Edge

Astronaut, signals from outside the solar system reach your fleet through the **ingress gateway**: the spaceport arrival gate, the one door they all come through. With normal HTTPS, the gate shows its own ID badge (a certificate) to every visitor, and lets anyone in who can read it. That is right for a public website.

It is wrong for a partner system. Think of a supply company whose machines call your fleet's computers. The list of callers is short and known in advance, and nobody else should even get to knock. For that, the gate must check the **visitor's** badge too. Istio calls this `MUTUAL` TLS at the gateway. TLS (Transport Layer Security) is the sealed envelope that keeps a signal private on its way.

The change in the `Gateway` is one word. The change in the secret is one extra key. And when a visitor is turned away, it does not look like an HTTP error at all, so you need to know what to look for.

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

Every mission starts with a pre-flight check. Make sure you have the knowledge this module expects, know what is waiting in your playground, and have one small helper ready.

### What you should already know

- **The ingress gateway.** A `Gateway` opens a port on the gateway pods for some host names. A `VirtualService` linked to it with `gateways:` says where the signals go next.
- **HTTPS at the gateway with `SIMPLE` TLS.** The gateway shows a server certificate that it reads from a secret named in `credentialName`. That secret must live in the namespace of the gateway **pod**, not in the namespace of the `Gateway` object. The gateway picks the server by the host name the client sends in its first TLS message, called SNI (Server Name Indication).
- **Kubernetes basics.** Namespaces, Secrets, Services and `kubectl logs`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The fleet lives on the planet (namespace) **`starfleet`**:

| Ship | Its role in the fleet |
| --- | --- |
| `bridge` | The **flagship**: the web page astronauts see, on port `9080`. It is the ship you put behind the gate |
| `cargo`, `navcom`, `scout` v1, v2, v3 | The rest of the fleet. The bridge signals them to build its page |
| `shuttle` | Your client inside the mesh |

The ingress gateway lives on its own planet, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. Flight logs (access logs) are on. There is **no** certificate, **no** secret, **no** `Gateway` and **no** `VirtualService` yet: making them is your mission.

The Starfleet is the Istio docs' Bookinfo sample with space names. The paths built into the ships keep their old names, so the bridge answers on `/productpage`.

A `kind` cluster has no cloud load balancer. `astrona run` keeps two port forwards running for you:

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` |

Check them with `astrona port-forward list`. A refused handshake ends the `8443` forward, and astrona starts it again within about ten seconds. A signal sent in that gap gets `000` and curl exit code `7`.

You make the certificates yourself, with `openssl` on your own machine. Work in one folder for the whole module, because every command uses the relative path `certs/`. You also need `istioctl` 1.30.5 on your own machine.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### One helper to paste first

Paste this into each new terminal, in your working folder. It sends one HTTPS signal through the gate to the bridge, trusts your own CA, and prints the HTTP status code and curl's exit code. Any curl options you add, such as a client certificate, are passed on:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

`--resolve` sends the real host name, `starfleet.example.com`, to your local port. The gate needs that name to pick the right server. The certificate files it uses are made in the first part.

## The parts, in order

1. [Issue The Fleet's Badges](./course-01-issue-the-fleet-badges.md): what a CA is, and making the CA, the server certificate and the client certificate.
2. [Make The Gate Ask For A Badge](./course-02-make-the-gate-ask-for-a-badge.md): the three-key secret, the `MUTUAL` gateway, and the first test with and without a badge.
3. [Turn Away Strangers And Prove It](./course-03-turn-away-strangers-and-prove-it.md): a badge from another CA, and reading the proof from the gateway's proxy.
4. [Two Secret Layouts And What A Badge Proves](./course-04-two-secret-layouts-and-what-a-badge-proves.md): the separate `-cacert` secret, and what to do after the badge check.
5. [Wrap-Up](./course-05-wrap-up.md): a recap, your missions, and cleaning up.

## Why this matters

Partner and machine-to-machine APIs often need more than a password. With `MUTUAL` TLS, a caller without the right badge cannot even send a request, so nothing behind the gate spends any effort on it. The exam asks you to set this up by hand and prove it works. The proof is the hard part, because a turned-away visitor gets no status code, and a working signal on its own does not show that the badge check is on.
