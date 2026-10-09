# Prove Where TLS Ends

A `200` looks the same whether the ingress gateway decrypted the traffic or passed it through. So a `200` alone proves nothing about the mode. On the exam, and in real work, you need proof that the backend itself ended TLS (Transport Layer Security), and that nothing in between could read the stream.

This chapter collects three kinds of evidence, each from a different place. The client shows which certificate it got. The gateway's own configuration shows how it handles the port. And the gateway's route table and access log show what is missing. The commands below need the passthrough setup for `tls-backend` applied: the `Gateway` `vault-gateway` and the `VirtualService` `tls-backend` in `starfleet`.

## Whose certificate answered

The strongest evidence comes from the client side. In passthrough, the backend at the end finishes the TLS handshake, so the client gets the **backend's** certificate. If the gateway had ended TLS, the client would get the gateway's certificate instead.

<!-- astrona:playground:renew -->

Ask the gateway for the certificate it returns for the SNI (Server Name Indication) name of `tls-backend`:

```sh
show_certificate vault.starfleet.example.com
```

```text
subject=CN=vault.starfleet.example.com, O=vault
sha256 Fingerprint=8D:AA:16:3B:52:67:DB:24:B8:5B:4E:2E:AA:B1:76:CB:C3:40:76:49:68:C5:F9:3C:ED:C7:33:B6:1B:95:05:B4
```

This is the same fingerprint as the certificate file on the disk of `tls-backend`, `/etc/nginx/certs/tls.crt`, which nginx inside that pod uses. `tls-backend` made the certificate when its pod started, and nothing in between replaced it or signed a new one. That is what "end to end" means in practice.

## What the gateway's listener holds

The same fact shows up inside the gateway. The gateway is an Envoy proxy, so `istioctl proxy-config` can read the configuration that `istiod`, Istio's control plane, sent to it. A listener is the part of Envoy that accepts connections on one port and decides where they go. Ask the gateway for its listener on port `443`:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress --port 443
```

```text
ADDRESSES PORT MATCH                            DESTINATION
0.0.0.0   443  SNI: vault.starfleet.example.com Cluster: outbound|8443||tls-backend.starfleet.svc.cluster.local
```

The `MATCH` column shows your `sniHosts` turned into a match on the SNI name. The `DESTINATION` is a cluster, not a route. In Envoy a cluster is a group of backend endpoints, here the `tls-backend` Service on port `8443`. A server that ended TLS would show an HTTP route here instead. So the TLS inspector reads the SNI name, and the gateway sends the stream straight to that cluster.

## What is missing

The last proof is an absence. A gateway that ends TLS builds an HTTP route for each host. A passthrough server builds none, because there is no HTTP to route. List the gateway's HTTP routes:

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

You see the routes of `bridge` on port `80`, because the gateway reads those plain HTTP requests. The two `backend` rows are the gateway's own health and metrics pages. You see nothing for `vault.starfleet.example.com`. Here a missing route is not a fault to fix: it is the mode working.

The gateway's access log tells the same story from the traffic side. Send one request to `tls-backend`:

```sh
tls_status vault.starfleet.example.com
```

```text
200
```

The gateway writes its access log in batches, so wait a few seconds. Then read its last log line:

```sh
kubectl logs -n istio-ingress deploy/istio-ingress --tail=1
```

```text
[2026-10-09T10:27:00.681Z] "- - -" 0 - - - "-" 542 2221 12 - "-" "-" "-" "-" "10.244.0.14:8443" outbound|8443||tls-backend.starfleet.svc.cluster.local 10.244.0.6:42530 127.0.0.1:443 127.0.0.1:50748 vault.starfleet.example.com -
```

Where an HTTP line shows the method, the path and the protocol, this one shows `"- - -"`, and the status code is `0`. The gateway never saw any of them. The line still shows the bytes moved (`542` in, `2221` out), the `tls-backend` pod it reached (`10.244.0.14:8443`), the cluster it chose and, near the end, the SNI name it routed on. This is the log line of a gateway that passed the connection through.

Together, the three pieces of evidence leave no other explanation. The certificate the client gets says `tls-backend` ended TLS. The gateway's listener and its missing HTTP route say the gateway never tried. You can now set up passthrough and prove it. What you have not seen yet is how a passthrough setup looks when it is wrong.

## Common pitfalls

> [!WARNING]
> - **Taking a `200` as proof of passthrough.** All TLS modes can give `200`. Check the certificate the client gets.
> - **"Fixing" the missing HTTP route.** For a passthrough host, no HTTP route is correct.
> - **Comparing only the subject line.** A gateway certificate can carry the same name. The fingerprint tells two certificates apart.
> - **Expecting a status code in the gateway's access log.** For passthrough traffic the gateway logs a connection, not a request.

## Your mission: Route An Encrypted Stream By SNI

You can now set up a passthrough server, route it on the SNI name, and prove the backend ended TLS itself. The graded lab asks you to expose a backend that keeps its own certificate through the shared ingress gateway, without the gateway decrypting anything.

This lab uses its own small app, not the Starfleet: a `tls-backend` in the namespace `passthrough-demo` with the host `secure.ica.local`, behind the gateway `istio-ingressgateway` in `istio-system`. The task explains it in full.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-03
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-040-03
astrona start ats-015-playground-040-03
```
