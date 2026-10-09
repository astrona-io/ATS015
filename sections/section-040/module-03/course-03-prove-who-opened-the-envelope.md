# Prove Who Opened The Envelope

Astronaut, a `200` looks the same whether the gate opened the signal or passed it through. So a `200` alone proves nothing about the mode. This part collects three kinds of evidence: the certificate the visitor gets, the gate's own listener, and what is missing from the gate's route table and flight log.

The commands below need the vault's passthrough setup applied: the `Gateway` `vault-gateway` and the `VirtualService` `tls-backend` in `starfleet`.

## Evidence 1: whose certificate answered

In passthrough, the ship at the end finishes the handshake, so the visitor gets the **ship's** certificate. If the gate had ended TLS, the visitor would get the gate's certificate instead.

<!-- astrona:playground:renew -->

### Read the certificate through the gate

Ask the gate for the certificate it hands out for the vault's SNI name:

```sh
show_certificate vault.starfleet.example.com
```

```text
subject=CN=vault.starfleet.example.com, O=vault
sha256 Fingerprint=8D:AA:16:3B:52:67:DB:24:B8:5B:4E:2E:AA:B1:76:CB:C3:40:76:49:68:C5:F9:3C:ED:C7:33:B6:1B:95:05:B4
```

Compare the fingerprint with the one you read from the vault's disk, with no gate on the path. They are the same. The certificate was made by the vault when its pod started, and nothing in between replaced it or signed a new one. That is what "end to end" means in practice.

## Evidence 2: what the gate's listener holds

The same fact shows up inside the gate. The gate is an Envoy proxy, so `istioctl proxy-config` reads the orders mission control (`istiod`) gave it.

### Read the port 443 listener

Ask the gate for its listener on port `443`:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress --port 443
```

```text
ADDRESSES PORT MATCH                            DESTINATION
0.0.0.0   443  SNI: vault.starfleet.example.com Cluster: outbound|8443||tls-backend.starfleet.svc.cluster.local
```

The `MATCH` column shows your `sniHosts` turned into a match on the SNI name. The `DESTINATION` is a cluster, the vault's Service on port `8443`, and not a route. A server that ended TLS would show an HTTP route here instead. The TLS inspector reads the SNI name, and the gate sends the stream straight to that cluster.

## Evidence 3: what is missing

The last proof is an absence. A gate that ends TLS builds an HTTP route for each host. A passthrough server builds none, because there is no HTTP to route.

### Look for an HTTP route that is not there

List the gate's HTTP routes:

```sh
istioctl proxy-config routes deploy/istio-ingress -n istio-ingress
```

```text
NAME        VHOST NAME                   DOMAINS                   MATCH                  VIRTUAL SERVICE
http.80     starfleet.example.com:80     starfleet.example.com     /productpage           bridge.starfleet
http.80     starfleet.example.com:80     starfleet.example.com     /static*               bridge.starfleet
            backend                      *                         /stats/prometheus*     
            backend                      *                         /healthz/ready*
```

You see the bridge's routes on port `80`, because the gate reads those plain HTTP signals. The two `backend` rows are the gate's own health and metrics pages. You see nothing for `vault.starfleet.example.com`. Here a missing route is not a fault to fix: it is the mode working.

### Read the gate's flight log

Send one signal to the vault:

```sh
tls_status vault.starfleet.example.com
```

```text
200
```

The gate writes its flight log in batches, so wait a few seconds. Then read its last log line:

```sh
kubectl logs -n istio-ingress deploy/istio-ingress --tail=1
```

```text
[2026-10-09T10:27:00.681Z] "- - -" 0 - - - "-" 542 2221 12 - "-" "-" "-" "-" "10.244.0.14:8443" outbound|8443||tls-backend.starfleet.svc.cluster.local 10.244.0.6:42530 127.0.0.1:443 127.0.0.1:50748 vault.starfleet.example.com -
```

Where an HTTP line shows the method, the path and the protocol, this one shows `"- - -"`. The status code is `0`. The gate never saw any of them. The line still shows the bytes moved (`542` in, `2221` out), the vault pod it reached (`10.244.0.14:8443`), the cluster it chose and, near the end, the SNI name it routed on. This is the black box of a gate that passed the signal through.

Together, the three pieces of evidence leave no other explanation. The certificate says the vault ended TLS. The listener and the missing route say the gate never tried.

## Common pitfalls

> [!WARNING]
> - **Taking a `200` as proof of passthrough.** All TLS modes can give `200`. Check the certificate the visitor gets.
> - **"Fixing" the missing HTTP route.** For a passthrough host, no HTTP route is correct.
> - **Comparing only the subject line.** A gate certificate can carry the same name. The fingerprint tells two certificates apart.
> - **Expecting a status code in the gate's flight log.** For passthrough traffic the gate logs a connection, not a request.

> *The visitor's certificate says who ended TLS; the gate's listener and its missing HTTP route say the gate never tried.*

## Your mission: Route An Encrypted Stream By SNI

You can now set up a passthrough server, route it on the SNI name, and prove the ship ended TLS itself. Now prove it in a graded mission: expose a backend that keeps its own certificate through the shared gate, without the gate decrypting anything.

This mission uses its own small app, not the Starfleet: a `tls-backend` in the namespace `passthrough-demo` with the host `secure.ica.local`, behind the gate `istio-ingressgateway` in `istio-system`. The task explains it in full.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-03
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-040-03
astrona start ats-015-playground-040-03
```
