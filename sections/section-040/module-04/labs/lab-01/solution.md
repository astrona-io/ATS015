# Solution Walkthrough

Two objects, two halves of one job, astronaut. The `ServiceEntry` decides **where** the shuttle's sidecar connects, and the `DestinationRule` decides **how**. httpbin.org tells you at the end whether the seal was added.

---

## Step 1: See the starting point

Ask httpbin.org how the shuttle's plain signal arrives today, then read the shuttle's flight log:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://httpbin.org/get | grep '"url"'
sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```
  "url": "http://httpbin.org/get"
[2026-10-09T10:54:29.043Z] "- - -" 0 - - - "-" 78 485 356 - "-" "-" "-" "-" "3.225.83.162:80" PassthroughCluster 10.244.0.6:39254 3.225.83.162:80 10.244.0.6:39242 - -
```

The sidecar writes its flight log in small batches, so the `sleep 2` gives it time. If the line you see is an older one, run the `kubectl logs` command again.

httpbin.org says `http://`: the signal crossed the internet unsealed. The flight log shows `"- - -"` and `PassthroughCluster`: httpbin.org is not on the star chart, so the sidecar did not even read the signal as HTTP.

```sh
astrona submit -c sections/section-040/module-04/labs/lab-01
```

```
Proctor
FAIL: ServiceEntry 'httpbin-org' not found in starfleet
  FAIL  verify-tls-origination (0.11s)
```

The output is shortened: `astrona submit` also prints a score and the attempt number.

---

## Step 2: Chart the planet, port 80 pointing at 443

A `ServiceEntry` adds a planet from another solar system to the star chart. Port `80` with protocol `HTTP` lets the sidecar read the shuttle's plain signal. `targetPort: 443` makes the sidecar connect to port `443` on the real server. Port `443` keeps the shuttle's own `https://` signals working.

Save this as `serviceentry-httpbin-org.yaml`:

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
    targetPort: 443
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

Apply it:

```sh
kubectl apply -f serviceentry-httpbin-org.yaml
```

Then check the result:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/get
sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```
400
[2026-10-09T10:55:01.481Z] "GET /get HTTP/1.1" 400 - via_upstream - "-" 0 220 239 236 "-" "curl/8.11.1" "dd87d5db-5806-40e3-815e-51f70ebf1ae9" "httpbin.org" "18.233.182.23:443" outbound|80||httpbin.org 10.244.0.6:60730 98.88.155.171:80 10.244.0.6:43164 - default
```

This is the half-done state. The sidecar reads the signal (method, path and status are in the log) and sends it to port `443`, but still as plain HTTP. httpbin.org answers `400`, and `via_upstream` says the answer came from the server.

---

## Step 3: Seal port 80 and check the name

A `DestinationRule` holds the docking instructions. Put the `tls` block under `portLevelSettings` for port `80`, the port the shuttle calls:

- **`mode: SIMPLE`**: the sidecar starts a normal one-way TLS connection.
- **`sni: httpbin.org`**: the server name the sidecar writes on the envelope.
- **`subjectAltNames: [httpbin.org]`**: the name the server's certificate must carry. Without it, the sidecar only checks that a trusted authority signed the certificate.

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

Do not put `tls` at the top of `trafficPolicy`. That seals port `443` too, and the shuttle's own `https://` signals would get a second seal. When this lab was tested, `curl https://httpbin.org/get` from the shuttle then failed with exit code `35`, and the grader answered `FAIL: the DestinationRule sets tls at the TOP level of trafficPolicy`.

---

## Step 4: The decisive test

Ask httpbin.org again, and read the flight log:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://httpbin.org/get | grep '"url"'
sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1
```

```
  "url": "https://httpbin.org/get"
[2026-10-09T10:56:27.174Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 930 507 506 "-" "curl/8.11.1" "2c0505cc-c51d-4192-a0f6-5c312b27ef5d" "httpbin.org" "52.21.224.34:443" outbound|80||httpbin.org 10.244.0.6:52106 32.194.118.12:80 10.244.0.6:36804 - default
```

The shuttle sent `http://`, and httpbin.org was reached on `https://`. The log line shows the cluster `outbound|80||httpbin.org` (the port the shuttle called) and an upstream address on `:443` (where the sidecar really connected). If the answer still says `http://`, the new orders have not reached the sidecar yet: wait a few seconds and run it again.

Check that the shuttle's own sealed signals still work:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/get
```

```
200
```

---

## Step 5: Proof from the proxy

Each port of `httpbin.org` is a cluster in the shuttle's proxy. Only the port `80` cluster should seal its connections:

```sh
istioctl proxy-config cluster deploy/shuttle -n starfleet --fqdn httpbin.org --port 80 -o json | grep -e '"name": "envoy.transport_sockets' -e '"sni"'
istioctl proxy-config cluster deploy/shuttle -n starfleet --fqdn httpbin.org --port 443 -o json | grep -c '"name": "envoy.transport_sockets.tls'
```

```
            "name": "envoy.transport_sockets.tls",
                "sni": "httpbin.org"
0
```

The port `80` cluster carries the TLS transport socket and the SNI name. `0` for port `443` means that cluster is not sealed by the sidecar: the shuttle's own TLS passes through as it is.

Send it for grading:

```sh
astrona submit -c sections/section-040/module-04/labs/lab-01
```

```
Proctor
PASS: the ServiceEntry sends port 80 to 443, the DestinationRule seals only port 80 with SIMPLE, sni and subjectAltNames httpbin.org, the shuttle's proxy holds a TLS transport socket on port 80 only, a plain http:// signal reached httpbin.org as https on port 443, and the shuttle's own https:// signals still work
  PASS  verify-tls-origination (4.04s)
```

The output is shortened: `astrona submit` also prints the score and the attempt number. If the grade fails right after you applied the `DestinationRule`, wait about a minute and submit again: new orders can take a little while to reach the sidecar.

---

## Common mistakes

- **No `targetPort: 443`.** The sidecar sends its TLS handshake to port `80`, and the call fails with `503 URX,UF` and `WRONG_VERSION_NUMBER`.
- **No `DestinationRule`.** Plain HTTP reaches port `443`, and httpbin.org answers `400`.
- **`tls` on port `443` or at the top of `trafficPolicy`.** Port `443` gets sealed too, and the shuttle's own `https://` signals fail.
- **A wrong name in `subjectAltNames`.** The sidecar refuses the server: `503 URX,UF` and `CERTIFICATE_VERIFY_FAILED`.
- **`insecureSkipVerify: true`.** It switches the certificate check off. The grader rejects it.
- **Changing the shuttle to call `https://`.** Then the sidecar sees a sealed envelope and cannot originate anything.
