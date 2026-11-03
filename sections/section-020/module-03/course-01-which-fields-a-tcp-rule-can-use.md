# Which Fields A TCP Rule Can Use

When a request arrives at a web service, the sidecar proxy can read a method, a path and headers. When bytes arrive at a database, it can read none of those. The proxy sees a TCP connection: a source address, a destination address and port, and, with mutual TLS (mTLS), the caller's certificate. This chapter lists what a policy can match on a connection, then deploys a TCP server so the next chapters have something to protect.

## Two levels of matching

The sidecar proxy (Envoy) is a proxy container that Istio adds to each pod; all traffic of the pod passes through it. It protects a workload at one of two levels. At the HTTP level, the proxy parses each request and a rule can use every field. At the TCP level, the proxy handles one connection at a time and a rule can use only what a connection carries.

Istio decides the level from the protocol of the port. A Kubernetes Service port named `http`, or one that sets `appProtocol: http`, is treated as HTTP. A port named `tcp`, or any name Istio does not recognise as HTTP, is treated as TCP. Here the port names are `tcp` and `tcp-other`, so both are TCP.

An `AuthorizationPolicy` rule has three parts. The `from` part describes the caller (`source`), the `to` part describes the target (`operation`), and `when` holds extra conditions. These fields describe a connection and work on TCP:

| Part | Field | What it matches |
| --- | --- | --- |
| `from.source` | `principals`, `notPrincipals` | The caller's identity from its mTLS certificate |
| `from.source` | `namespaces`, `notNamespaces` | The caller's namespace, taken from the same certificate |
| `from.source` | `ipBlocks`, `notIpBlocks` | The address of the direct peer of the connection |
| `to.operation` | `ports`, `notPorts` | The destination port of the connection |

These fields exist only in HTTP and have no meaning on a TCP connection: `hosts`, `methods` and `paths` in `to.operation`, and every condition in `when` that reads a request header or a JWT claim. The `AuthorizationPolicy` reference marks `hosts`, `methods` and `paths` with "Must be used only with HTTP".

Because identity comes from the certificate, `principals` and `namespaces` need mTLS. Without it the proxy has no caller identity to compare. The namespace in this playground already uses `STRICT` mTLS, so both fields work.

## Deploy the TCP server

`tcp-echo` is a small server from the Istio samples. It listens on three ports and replies `hello` plus the text it receives. Its Kubernetes Service lists only ports `9000` and `9001`. Port `9002` is left out on purpose, so the only way to reach it is the pod IP. A connection to a pod IP does not match any Service port, so the sidecar proxy handles it with its pass-through filter chain, the default handler for traffic with no matching listener.

The playground already deployed it. List its pod and Service:

```sh
kubectl get pods,svc -n starfleet -l app=tcp-echo
```

The pod shows `2/2` containers: the server and the `istio-proxy` sidecar. The Service shows ports `9000/TCP,9001/TCP`.

Send a connection to each port with no policy in place:

```sh
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
tcp_from shuttle $ECHO_IP 9002
tcp_from relay tcp-echo 9000
```

All four lines print `allowed`, and each reply begins with `hello`. With no `AuthorizationPolicy`, Istio allows every connection, including the one to `9002` that the Service does not list.

## Where the rules run in the proxy

`istiod` is Istio's control plane. It turns each `AuthorizationPolicy` into configuration and sends it to the sidecar proxy with xDS, the protocol `istiod` uses to push configuration to proxies while they run. The proxy then applies the rules in a filter. A filter is a step in the chain that Envoy runs for each connection or request.

Envoy has two places for authorization. The HTTP RBAC filter runs after Envoy has parsed a request, so it can read headers, methods and paths. The network RBAC filter runs on the raw connection, before any parsing, so it can read only the addresses, the port and the peer certificate. RBAC stands for role-based access control, the name Envoy uses for these allow and deny rules. For a TCP port, `istiod` installs the network filter.

You can look at the filters that `istiod` sent to the `tcp-echo` proxy. The listener on port `15006` is the one that receives all inbound traffic of the pod:

```sh
istioctl proxy-config listener deploy/tcp-echo -n starfleet --port 15006 -o json | grep -c rbac
```

Run it now, then run it again after you apply a policy in the next chapter, and compare the counts. A rule on a TCP port appears as a network filter, `envoy.filters.network.rbac`.

## Two checks that run before any policy

The policy is not the first check. The `PeerAuthentication` in `STRICT` mode runs earlier, at the TLS handshake. A caller without a certificate never reaches the rules. Try the `drifter`, which has no sidecar proxy:

```sh
kubectl exec -n outpost deploy/drifter -- sh -c "echo test | nc -w 3 tcp-echo.starfleet 9000"
```

The connection is closed and no `hello` comes back. No `AuthorizationPolicy` is involved: the `STRICT` mode refuses a plain-text connection on its own. For a TCP workload this is the main reason to turn on mTLS first, because without it no rule can name a caller.

The second check concerns `ipBlocks`. For a TCP connection the proxy compares `ipBlocks` with the address of the direct peer. In a mesh with sidecar proxies, the direct peer is the sidecar proxy of the caller or, for traffic from outside, a gateway or node address. Prefer `principals` for callers inside the mesh, because an identity stays the same when a pod gets a new address.

## Read the connection in the access log

The access log of the receiving sidecar proxy shows what the proxy knew about each connection. Read the last lines from the `tcp-echo` proxy:

```sh
kubectl logs -n starfleet -l app=tcp-echo -c istio-proxy --tail=5
```

For a TCP connection the log line has no method, path or status code. It shows the bytes received and sent, the duration, and the source and destination addresses. This is the full set of facts the proxy has, and it is the reason HTTP fields cannot match.

You now know which fields exist on a connection: caller identity, caller namespace, caller address and destination port. The next chapter turns those fields into policies and shows what happens to a port the Service does not list.

## Common pitfalls

> [!WARNING]
> - **A Service port named `http` for a raw TCP server.** Istio then treats the traffic as HTTP, and a TCP client breaks or is parsed wrongly. Name TCP ports `tcp` or `tcp-<suffix>`, or set `appProtocol`.
> - **Expecting `principals` to work without mTLS.** With `PERMISSIVE` mode, a plain-text caller has no identity, so a rule on `principals` never matches it.
> - **Testing only the Service port.** A pod IP and a port the Service does not list reach the workload by another path. Test that path as well.
