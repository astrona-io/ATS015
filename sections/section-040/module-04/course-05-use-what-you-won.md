# Add A Timeout And Mutual TLS To An External Service

TLS origination is not only about encryption. Because the `shuttle` app sends a plain HTTP request to its own sidecar proxy (Envoy), the sidecar can read every request again. That brings back the request features of the mesh for a service outside the cluster. This part puts a timeout on an outside HTTPS service, and then shows what changes when the outside server wants a certificate from you too.

The commands below need the two objects for `httpbin.org` in `starfleet`: the `ServiceEntry` `httpbin-org` with port `80` (`targetPort: 443`) and port `443`, and the `DestinationRule` `httpbin-org` with `tls.mode: SIMPLE` for port `80`. With both in place, `http://httpbin.org/get` from the `shuttle` pod answers `200`, and httpbin.org reports `"url": "https://httpbin.org/get"`.

## A timeout on an outside HTTPS service

A route `timeout` is the longest time the sidecar waits for a response: if no response comes back in time, the sidecar stops waiting and answers with an error. It lives in a `VirtualService`, the object that holds routing rules. The sidecar can only apply it to a request it can read, so it works here only because the `shuttle` app sends plain HTTP and the sidecar starts TLS.

<!-- astrona:playground:renew -->

The commands below use a helper. Paste it into your terminal if you have not yet:

```sh
status_and_time() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 10 "$@"; }
```

### Add a VirtualService with a timeout

Save this as `virtualservice-httpbin-org.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin-org
  namespace: starfleet
spec:
  hosts:
  - httpbin.org
  http:
  - route:
    - destination:
        host: httpbin.org
    timeout: 2s
```

The `hosts` field names the `ServiceEntry` host, so this `VirtualService` applies to every HTTP request the `shuttle` pod sends to `httpbin.org`. The route keeps the request on the same host. Only the timeout is new.

Apply it:

```sh
kubectl apply -f virtualservice-httpbin-org.yaml
```

Then ask httpbin.org for a response that takes 4 seconds, and for a normal one:

```sh
status_and_time http://httpbin.org/delay/4
status_and_time http://httpbin.org/get
```

```
504 2.007945s
200 0.508405s
```

The `shuttle` pod's sidecar gave up after about 2 seconds and answered `504` itself. The normal request still answers `200`. Read the access log to see the sidecar's own reason:

```sh
kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=2
```

```
[2026-10-09T10:50:32.590Z] "GET /delay/4 HTTP/1.1" 504 UT response_timeout - "-" 0 24 2000 - "-" "curl/8.11.1" "a9f4378f-bfa7-462c-b3ed-6770090acd9e" "httpbin.org" "18.233.182.23:443" outbound|80||httpbin.org 10.244.0.6:36722 52.21.224.34:80 10.244.0.6:37576 - -
[2026-10-09T10:50:34.665Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 977 503 502 "-" "curl/8.11.1" "61819ae2-e743-4dba-8010-45e6018aa5ef" "httpbin.org" "32.194.118.12:443" outbound|80||httpbin.org 10.244.0.6:33986 32.194.118.12:80 10.244.0.6:47574 - -
```

**`UT`** means upstream timeout: the timeout ran out before the server answered. The `2000` after the byte counts is the time in milliseconds, exactly the `timeout: 2s` you set. If the `shuttle` app called `https://httpbin.org/delay/4` instead, the sidecar would see only encrypted bytes, and this timeout could never fire. Retries, fault injection and routing by path or header work the same way now. This is the main reason to use TLS origination.

## Mutual TLS to an outside service

`SIMPLE` is one-way TLS: the sidecar checks the server's certificate, and the server does not check yours. Some partners also want a certificate from **you**, so both sides check each other's certificate. That is `tls.mode: MUTUAL`. Everything else stays the same: it is still origination, still under `portLevelSettings` for the port the app calls, and still invisible to the app.

`MUTUAL` needs a client certificate and its private key. You give them to the sidecar in one of two ways:

| Field in the `tls` block | Where the files come from |
| --- | --- |
| `credentialName: <secret name>` | A Kubernetes secret in the **same namespace as the calling workload**, the one whose sidecar starts TLS |
| `clientCertificate`, `privateKey`, `caCertificates` | File paths inside the **sidecar container** (`istio-proxy`), not the app container |

The secret is usually the easier choice. File paths need the files mounted into the sidecar, which takes a pod change and a restart. With either form, every namespace that calls the partner needs its own copy of the client certificate. An egress gateway, an Envoy proxy at the edge of the mesh that outgoing traffic can pass through, can keep that certificate in one place instead.

## Common pitfalls

> [!WARNING]
> - **Expecting a timeout to work when the app calls `https://`.** The sidecar cannot see where an encrypted request starts or ends. The app must call `http://`.
> - **Reading `504` as a slow server answer.** With `UT` in the log, the `shuttle` pod's own sidecar cut the request off when the timeout ran out.
> - **Putting the `MUTUAL` secret in the wrong namespace.** On a sidecar, `credentialName` reads the secret from the calling workload's own namespace.
> - **File paths the sidecar cannot read.** `clientCertificate` and `privateKey` point into the `istio-proxy` container.

> *Once the sidecar starts TLS, an external HTTPS service gets the same timeouts and retries as any service in the mesh.*
