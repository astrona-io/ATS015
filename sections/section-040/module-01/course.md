# Terminate TLS At The Ingress Gateway

Astronaut, inside the mesh Istio seals every signal for you. Mission control (`istiod`) hands every ship its own certificate, and both ends check each other with a secret handshake (mutual TLS, or mTLS). Signals from outside the solar system are different. A browser or a partner system arrives at the spaceport arrival gate (the ingress gateway) and expects HTTPS. It checks the gate's certificate against a certificate authority it already trusts, so the gate must show a certificate **you** supply, not one the mesh made.

**TLS** (Transport Layer Security) is the seal on the signal: only the right receiver can open it. When the gateway **terminates TLS**, it holds the certificate, opens the sealed signal, and sends it on inside the mesh. The configuration for this is short. What makes it fail, for almost everyone the first time, is one namespace: the gateway reads its certificate from a Secret in **its own** namespace, not in the namespace where the `Gateway` object lives.

## Learning objectives

After this module you can:

- Make a small certificate authority and a server certificate with `openssl`, and say what the SAN (subject alternative name) is for.
- Store a certificate as a Kubernetes TLS Secret in the namespace the gateway pod runs in, and explain why that namespace.
- Write a `Gateway` with a `SIMPLE` TLS server that names the Secret with `credentialName`, and link a `VirtualService` to it.
- Test HTTPS with `curl --resolve` and `--cacert`, and prove which certificate the gateway showed.
- Redirect plain HTTP to HTTPS with `tls.httpsRedirect`, and replace a certificate without restarting the gateway.
- Find the cause of a failed handshake from curl's exit code, `istioctl proxy-config secret` and `istioctl analyze`.

## Before you start

Every mission starts with a pre-flight check. Make sure you have the knowledge this module expects, know what is waiting in your playground, and have one helper ready in your terminal.

### What you should already know

- **The arrival gate.** A `Gateway` opens a port on the ingress gateway for some host names. A `VirtualService` with a `gateways:` field says where the signals that come through go next.
- **Kubernetes basics.** Namespaces, Secrets, Services and `kubectl`.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **Istio 1.30.5**, installed with Helm, plus an ingress gateway. The fleet lives on the planet (namespace) **`starfleet`**:

| Ship | Its role in the fleet |
| --- | --- |
| `bridge` | The **flagship**: the web page astronauts see, on `/productpage`, port `9080`. It is the ship you put behind HTTPS |
| `cargo`, `navcom`, `scout` v1-v3 | The ships the bridge signals to build its page |
| `shuttle` | Your client inside the mesh |

The ingress gateway lives on its own planet, **`istio-ingress`**. Its Deployment and its Service are both called `istio-ingress`, and its pod carries the label **`istio=ingress`**. No certificate, no TLS Secret, no `Gateway` and no `VirtualService` exist yet: making them is your mission.

A `kind` cluster has no cloud load balancer. `astrona run` keeps two port forwards running instead: `127.0.0.1:8080` goes to the gateway's port `80`, and `127.0.0.1:8443` goes to its port `443`. Check them with `astrona port-forward list`. You also need `istioctl` 1.30.5 and `openssl` on your own machine.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

### One helper to paste first

Work in one folder for the whole module: the certificates you make go into `certs/` there. Paste this into each new terminal, in that folder. It sends one HTTPS signal to the bridge through the gateway, trusts your test certificate authority, and prints the status code and curl's exit code:

```sh
https_status() { curl -s -o /dev/null -w "%{http_code} " --cacert certs/starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
```

Any `curl` options you add are passed on, for example `https_status -v`. The helper only works once the certificates exist; you make them in the first part.

## How this module is organised

1. **[Give The Gate Its Certificate](./course-01-give-the-gate-its-certificate.md)**: make a certificate authority and a server certificate, and put them in a Secret where the gateway looks.
2. **[Open The HTTPS Door](./course-02-open-the-https-door.md)**: the `SIMPLE` TLS server, the `VirtualService`, and proof of which certificate the gateway showed.
3. **[Redirect And Rotate](./course-03-redirect-and-rotate.md)**: send plain HTTP to HTTPS, and replace a certificate with no restart. Ends with your first graded mission.
4. **[When The Handshake Fails](./course-04-when-the-handshake-fails.md)**: a Secret in the wrong namespace, a wrong host name, and how curl's exit codes point at the cause. Ends with a repair mission.
5. **[Wrap-Up](./course-05-wrap-up.md)**: what you learned, your missions, and cleaning up.

## Why this matters

Every service your users reach over the internet enters the mesh through a gate like this one, and almost all of them use HTTPS. The exam asks you to set it up by hand, under time pressure, and to prove it works. Most failures here give no error message at all: the objects are accepted, and the handshake simply fails. Knowing where the certificate must live, and how to read a failed handshake, turns a long search into a two-minute fix.
