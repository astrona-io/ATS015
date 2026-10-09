# Practice: Originate TLS For External Services

One exam-style task for this playground. Start the playground
first, and paste the helpers from [overview.md](./overview.md#helpers). The
solution uses them.

Try the task on your own first, then open the solution.

## Task: originate TLS to Google

> In namespace `starfleet`, the shuttle calls `http://www.google.com/`. Make
> the shuttle's sidecar send it to Google over HTTPS on port `443`. The
> shuttle keeps calling `http://`. Name both objects `google`.

<details><summary>Solution</summary>

Two objects do the work. The `ServiceEntry` adds `www.google.com` to Istio's
service registry and sends port `80` requests to port `443` on the real
server. The `DestinationRule` tells the sidecar to start TLS for port `80`
requests.

Save this as `serviceentry-google.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata: {name: google, namespace: starfleet}
spec:
  hosts: [www.google.com]
  ports:
  - {number: 80, name: http, protocol: HTTP, targetPort: 443}
  - {number: 443, name: https, protocol: HTTPS}
  location: MESH_EXTERNAL
  resolution: DNS
```

Apply it:

```bash
kubectl apply -f serviceentry-google.yaml
```

Save this as `destinationrule-google.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata: {name: google, namespace: starfleet}
spec:
  host: www.google.com
  trafficPolicy:
    portLevelSettings:
    - port: {number: 80}
      tls: {mode: SIMPLE}
```

Apply it:

```bash
kubectl apply -f destinationrule-google.yaml
```

Then check the result:

```bash
status_and_time http://www.google.com/
last_log_line
```

```
200 0.138963s
[2026-10-09T10:51:04.666Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 85658 130 92 "-" "curl/8.11.1" "9bfafa71-7ac4-4dcf-89e8-1e22bf5ce8f5" "www.google.com" "142.251.153.119:443" outbound|80||www.google.com 10.244.0.6:42044 142.251.152.119:80 10.244.0.6:34520 - default
```

The log line names the cluster `outbound|80||www.google.com`, the port the
shuttle called, and an upstream address on port `443`, where the sidecar
really connected.

</details>
