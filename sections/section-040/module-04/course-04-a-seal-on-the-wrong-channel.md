# Diagnose TLS Origination Failures

TLS origination has two halves, the `ServiceEntry` port with `targetPort: 443` and the `DestinationRule` with `tls.mode: SIMPLE`, and each half can be missing on its own. When that happens, the request fails, and the status code alone does not tell you which half to fix. On the exam and in real work, you need to name the cause from the symptom quickly.

One mistake is already familiar: without the `tls` block, the sidecar proxy (Envoy) sends plain HTTP to the TLS port, and the server answers `400`. This chapter causes the opposite mistake, a TLS connection sent to the plain HTTP port. Then it puts all three failures in one table.

The commands need the two objects for `httpbin.org` in `starfleet`: the `ServiceEntry` `httpbin-org` with port `80` (`targetPort: 443`) and port `443`, saved as `serviceentry-httpbin-org.yaml`, and the `DestinationRule` `httpbin-org` with `tls.mode: SIMPLE` for port `80`. With both in place, `http://httpbin.org/get` from the `shuttle` pod answers `200`.

## Forget the `targetPort`

Without `targetPort`, the `ServiceEntry` port `80` sends requests to port `80` on the real server. The `DestinationRule` still tells the sidecar to start TLS for everything on port `80`. So the sidecar starts a TLS handshake with a server port that only speaks plain HTTP.

To see what that looks like, paste the two helpers into your terminal if you have not yet:

<!-- astrona:playground:renew -->

```sh
status_and_time() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 10 "$@"; }
last_log_line() { sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1; }
```

Save the wrong version in its own file, so you can switch back easily. Save this as `serviceentry-httpbin-org-no-target-port.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin-org
  namespace: starfleet
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

Apply it:

```sh
kubectl apply -f serviceentry-httpbin-org-no-target-port.yaml
```

Then send a request and read the access log:

```sh
status_and_time http://httpbin.org/get
last_log_line
```

```
503 0.798410s
[2026-10-09T10:49:40.880Z] "GET /get HTTP/1.1" 503 URX,UF upstream_reset_before_response_started{remote_connection_failure|TLS_error:|268435703:SSL_routines:OPENSSL_internal:WRONG_VERSION_NUMBER:TLS_error_end} - "TLS_error:|268435703:SSL_routines:OPENSSL_internal:WRONG_VERSION_NUMBER:TLS_error_end" 0 121 792 - "-" "curl/8.11.1" "c0d24b36-5483-46ab-a1a5-4acfa4f5e52b" "httpbin.org" "32.194.118.12:80" outbound|80||httpbin.org - 98.88.155.171:80 10.244.0.6:56600 - default
```

If you still see `200`, `istiod` (Istio's control plane) has not pushed the new configuration to the sidecar yet. Wait a few seconds and send the request again.

The `shuttle` pod's sidecar answered `503` with `UF`, an upstream connection failure. The TLS error inside is **`WRONG_VERSION_NUMBER`**: the sidecar sent the opening of a TLS handshake, and the server on port `80` answered in plain HTTP. The sidecar could not read that answer as TLS.

The upstream address `"32.194.118.12:80"` ends in `:80`, and that is the clue: the TLS connection went to the plain HTTP port. To repair it, apply the correct `ServiceEntry` again:

```sh
kubectl apply -f serviceentry-httpbin-org.yaml
```

Then check the result:

```sh
status_and_time http://httpbin.org/get
last_log_line
```

```
200 0.896377s
[2026-10-09T10:50:04.122Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 930 886 885 "-" "curl/8.11.1" "bfe6eee9-9c23-4594-b55c-665dd6726952" "httpbin.org" "32.194.118.12:443" outbound|80||httpbin.org 10.244.0.6:33518 98.88.155.171:80 10.244.0.6:56476 - default
```

The upstream address `"32.194.118.12:443"` ends in `:443` again, and the call works.

## Three failures, three causes

You have now seen each half go missing, and the server's certificate check adds a third failure. Each one has its own symptom. Read the status code and the access log, then use this table:

| Symptom | Which part answered | Cause | Fix |
| --- | --- | --- | --- |
| `400` from the server, `via_upstream` in the log | httpbin.org | Plain HTTP sent to port `443`: the `DestinationRule` `tls` block is missing | Add `tls.mode: SIMPLE` for port `80` |
| `503 URX,UF` with `WRONG_VERSION_NUMBER` | the `shuttle` pod's sidecar | TLS sent to port `80`: the `ServiceEntry` `targetPort` is missing | Add `targetPort: 443` to port `80` |
| `503 URX,UF` with `CERTIFICATE_VERIFY_FAILED` | the `shuttle` pod's sidecar | The server's certificate does not match `subjectAltNames` or `caCertificates` | Fix the name or the certificate authority |

`via_upstream` in a log line means the answer came from the server itself, not from your sidecar. The first row is the only one where the request reached httpbin.org.

In short, `400` means TLS is missing, and `WRONG_VERSION_NUMBER` means TLS went to the wrong port. With the table and the upstream address, you can name the broken half of any TLS origination setup from one log line. What is left is to use what the working setup gives you: requests the sidecar can read again.

## Common pitfalls

> [!WARNING]
> - **Fixing only one half.** You need both `targetPort: 443` **and** `tls.mode: SIMPLE`. Each one alone fails, with a different symptom.
> - **Looking for the mistake in the `DestinationRule` when you see `WRONG_VERSION_NUMBER`.** The `tls` block is fine. The port is wrong: check `targetPort` in the `ServiceEntry`.
> - **Skipping the upstream address in the log.** `:80` or `:443` at the end of it tells you at once which port the sidecar really used.
