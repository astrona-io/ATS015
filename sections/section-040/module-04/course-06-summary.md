# Summary

Requests to services outside the cluster usually need TLS. This module was about who starts that TLS connection, and why letting the sidecar proxy (Envoy) do it keeps every request visible to the mesh.

## What you learned

When the app calls `https://` itself, its sidecar sees only encrypted bytes: the destination address, the SNI (Server Name Indication) name, byte counts and whether the connection worked. The access log shows `"- - -"` and status `0`, and no timeout, retry or route can act on the request. TLS can be started by the app, by its own sidecar or by an egress gateway. **TLS origination** at the sidecar means the app calls `http://`, and its sidecar encrypts the request before it leaves the pod.

Origination needs two objects, and each does one half of the job. The `ServiceEntry` adds the outside host to the service registry, with port `80` (`HTTP`, `targetPort: 443`) for the app's plain requests and port `443` (`HTTPS`) for its own `https://` calls; it decides **where** the sidecar connects. The `DestinationRule` puts `tls.mode: SIMPLE` and `sni` under `portLevelSettings` for port `80`; it decides **how**. The proof comes from two sides: httpbin.org reports `"url": "https://httpbin.org/get"`, and the port `80` cluster in the proxy carries `envoy.transport_sockets.tls`.

A signed certificate is not enough on its own, because it must also belong to the right server. `subjectAltNames` lists the names the server's certificate must carry, while `sni` is only the name the sidecar asks for. Without `caCertificates`, the sidecar trusts the usual public certificate authorities.

Each missing piece has its own symptom, which you read from the status code and the access log:

- `400` with `via_upstream`: the server got plain HTTP on port `443`, so the `DestinationRule` `tls` block is missing.
- `503 URX,UF` with `WRONG_VERSION_NUMBER`: the sidecar sent TLS to port `80`, so `targetPort: 443` is missing. The upstream address ends in `:80`.
- `503 URX,UF` with `CERTIFICATE_VERIFY_FAILED`: the server's certificate does not match `subjectAltNames` or `caCertificates`.

Because the sidecar reads the plain HTTP request, an outside HTTPS service gets the mesh's request features. A `VirtualService` with `timeout: 2s` turns a slow call into `504 UT`, cut off by the `shuttle` pod's own sidecar. When the server also wants a client certificate, `tls.mode: MUTUAL` adds one, from a secret in the calling workload's namespace (`credentialName`) or from files in the `istio-proxy` container.

In short: the app speaks plain HTTP to its own sidecar, and the sidecar starts TLS, checks the server's name and connects to port `443`.

<!-- astrona:playground:destroy -->
