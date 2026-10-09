# Overview: Originate TLS For External Services (Playground)

This is a **playground**, not a lab. It
starts a fresh cluster, installs Istio and the shuttle, and then waits. There
is no task, no `astrona submit` and no pass or fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only, no
  gateways). `istiod` is Istio's control plane: it sends configuration to
  every proxy.
- The mesh at its **`ALLOW_ANY`** default, so pods may send requests to any
  outside host. This module is about **who starts TLS** for the request, not
  about whether it may leave.
- Mesh-wide **access logs**, so every proxy writes one line per request. You
  read the `shuttle` pod's access log with
  `kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1`.
- Namespace **`starfleet`** (the namespace you work in), labelled
  `istio-injection=enabled`, with **`shuttle`**, your client pod inside the
  mesh. You send every test request from it with the `curl` command. It shows
  `2/2`: the app plus its `istio-proxy` sidecar proxy (Envoy).
- **No `ServiceEntry`, `DestinationRule` or `VirtualService`.** Writing them
  is the module.

### Outbound internet

This playground calls `httpbin.org` on ports `80` and `443`. **Without
outbound internet access you see network failures, not mesh behaviour.** Run a
plain `curl https://httpbin.org/get` on your own machine first.

## Helpers

Paste these once in each new terminal. The first prints the status code and
the time of one request from the `shuttle` pod. The second prints the last
line of the `shuttle` pod's access log.

```sh
status_and_time() { kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 10 "$@"; }
last_log_line() { sleep 2; kubectl logs -n starfleet deploy/shuttle -c istio-proxy --tail=1; }
```

Use them like this: `status_and_time http://httpbin.org/get`, then
`last_log_line`.

## Things to try

The module's parts show the full YAML for every step. The same files are in
`examples/01-egress-tls-origination/` in this folder, if you cloned the
repository.

- Ask httpbin.org how it was reached before anything else:
  `kubectl exec -n starfleet deploy/shuttle -- curl -s http://httpbin.org/get | grep '"url"'`.
  It says `http://`.
- Apply only the `ServiceEntry` with `targetPort: 443`. The server answers
  `400`: plain HTTP arrived on its TLS port.
- Add the `DestinationRule` with `tls.mode: SIMPLE` on port `80`. The same
  call now reports `"url": "https://httpbin.org/get"`.
- Put a wrong name in `subjectAltNames` and read the `503`,
  `URX,UF` and `CERTIFICATE_VERIFY_FAILED` in the access log.
- Remove `targetPort` from the `ServiceEntry` and read
  `WRONG_VERSION_NUMBER`.
- Add a `VirtualService` with `timeout: 2s` and call
  `http://httpbin.org/delay/4`.
- Compare `istioctl proxy-config cluster deploy/shuttle -n starfleet --fqdn httpbin.org --port 80 -o json`
  before and after the `DestinationRule`. Look for
  `envoy.transport_sockets.tls`.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete virtualservice,destinationrule,serviceentry --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-040-04`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-040-04`.
- The shuttle shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-040-04
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

One exam-style task for this playground. Start the playground
first, and paste the helpers from the Helpers section above. The
solution uses them.

Try the task on your own first, then open the solution.

### Task: originate TLS to Google

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
