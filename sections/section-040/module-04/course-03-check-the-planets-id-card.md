# Verify The Server Certificate Name

An encrypted request is only safe if it reaches the right server. When the sidecar proxy (Envoy) starts TLS for a request, it is the TLS client, so it is the one that must check who answers. This part shows how to make the sidecar check the server's name, and what it looks like when the name is wrong.

The commands below need the two objects for `httpbin.org` in `starfleet`: the `ServiceEntry` `httpbin-org` with port `80` (`targetPort: 443`) and port `443`, and the `DestinationRule` `httpbin-org` with `tls.mode: SIMPLE` and `sni: httpbin.org` for port `80`. With both in place, `http://httpbin.org/get` from the `shuttle` pod answers `200`, and httpbin.org reports `"url": "https://httpbin.org/get"`.

## What the sidecar checks in a certificate

A **certificate** is a file that proves a server's identity. A certificate authority (CA) signs it, and clients that trust that CA accept it. In `SIMPLE` mode, the sidecar checks that the certificate was signed by a CA it trusts. When you set no `caCertificates`, it uses its default list of public CAs, the same ones a web browser trusts. For a server with a private certificate authority, you set `caCertificates` to that authority's certificate. Because no `caCertificates` is set here, `istioctl analyze -n starfleet` prints a warning, `IST0129`, saying "no caCertificates are set to validate server identity". It is only a reminder: the sidecar still checks the certificate against the public CAs.

The signature alone does not say **whose** certificate it is. The field `subjectAltNames` does: it lists the names the server's certificate must carry. If the certificate carries none of them, the sidecar refuses the connection.

## See a wrong name fail

The quickest way to learn the symptom is to cause it on purpose. Put a name in `subjectAltNames` that httpbin.org's certificate does not carry.

<!-- astrona:playground:renew -->

The commands below use two helpers. Paste them into your terminal if you have not yet:

```sh
status_and_time() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 10 "$@"; }
last_log_line() { sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1; }
```

### Ask for the wrong name

Save this as `destinationrule-httpbin-org-wrong-san.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin-org
  namespace: starfleet
spec:
  host: httpbin.org
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        sni: httpbin.org
        subjectAltNames:
        - wrong.example.com
```

Apply it:

```sh
kubectl apply -f destinationrule-httpbin-org-wrong-san.yaml
```

Then send a request and read the access log:

```sh
status_and_time http://httpbin.org/get
last_log_line
```

```
503 0.776696s
[2026-10-09T10:48:40.976Z] "GET /get HTTP/1.1" 503 URX,UF upstream_reset_before_response_started{remote_connection_failure|TLS_error:|268435581:SSL_routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED:verify_cert_failed:_SAN_matcher,_certificate_SANs_are_[httpbin.org,_*.httpbin.org]:TLS_error_end} - "TLS_error:|268435581:SSL_routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED:verify_cert_failed:_SAN_matcher,_certificate_SANs_are_[httpbin.org,_*.httpbin.org]:TLS_error_end" 0 121 768 - "-" "curl/8.11.1" "62ed5740-e52e-4b36-a46e-374b7b83b8a3" "httpbin.org" "32.194.118.12:443" outbound|80||httpbin.org - 98.89.203.252:80 10.244.0.6:47066 - default
```

If you still see `200`, `istiod` has not pushed the new configuration to the sidecar yet: wait a few seconds and send the request again.

The `shuttle` pod's sidecar answered `503` itself. The access log explains why:

- **`UF`** means upstream connection failure: the connection to the server failed.
- **`URX`** means the sidecar gave up after its retries or connection attempts ran out.
- **`CERTIFICATE_VERIFY_FAILED`** is the TLS error inside: the sidecar read the server's certificate, and `wrong.example.com` is not in it. The log even lists the names the certificate does carry: `certificate_SANs_are_[httpbin.org,_*.httpbin.org]`.

The request never reached httpbin.org. The check happened during the TLS handshake (the first messages, where both sides agree on the encryption and the server shows its certificate), before any request was sent.

## Ask for the right name

Now set the name httpbin.org's certificate really carries. This is the version to keep.

### Fix the DestinationRule

Save this as `destinationrule-httpbin-org.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin-org
  namespace: starfleet
spec:
  host: httpbin.org
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        sni: httpbin.org
        subjectAltNames:
        - httpbin.org
```

Apply it:

```sh
kubectl apply -f destinationrule-httpbin-org.yaml
```

Then check the result:

```sh
status_and_time http://httpbin.org/get
kubectl exec -n starfleet deploy/shuttle -- curl -s http://httpbin.org/get | grep '"url"'
```

```
200 0.506353s
  "url": "https://httpbin.org/get"
```

The name matches, the handshake succeeds, and the request arrives over TLS again.

## Why `sni` alone checks nothing

`sni` and `subjectAltNames` look alike, but they do different jobs:

| Field | Job |
| --- | --- |
| `sni` | The name the sidecar **sends in the TLS handshake**, so the server knows which certificate to show |
| `subjectAltNames` | The names the sidecar **requires in the certificate** it gets back |

A wrong `sni` is not caught at httpbin.org. When the course was tested, httpbin.org answered any SNI name with its normal certificate, and that certificate is signed by a trusted CA, so the call still worked. If a task says "verify the server certificate" or "check the server's name", set `subjectAltNames`. For a private certificate authority, also set `caCertificates`.

## Common pitfalls

> [!WARNING]
> - **Setting only `sni` and calling it a check.** `sni` is what the sidecar asks for. `subjectAltNames` is what it insists on.
> - **Reading `503 UF` as a server problem.** With `CERTIFICATE_VERIFY_FAILED` in the log, the `shuttle` pod's own sidecar refused the server. The request never got past the handshake.
> - **Using `insecureSkipVerify: true` to make the error go away.** It switches the whole certificate check off. Fix the name or the `caCertificates` instead.

> *A trusted signature proves the certificate is real. `subjectAltNames` proves it belongs to the server you wanted.*

## Your mission: Originate TLS To An External Service Lab

You can now make the `shuttle` pod's sidecar originate TLS for a plain request to an external service, and make it check the server's name. The graded lab asks you to add `httpbin.org` with a `ServiceEntry`, originate TLS for the `shuttle` pod's plain `http://` requests, and require the right name in the server's certificate.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-04
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-04/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-04/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-040-04-01
astrona start ats-015-playground-040-04
```
