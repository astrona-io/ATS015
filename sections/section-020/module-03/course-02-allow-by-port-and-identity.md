# Allow By Port And Identity

A TCP server has no paths to protect, so the two useful questions are which ports a caller may reach and which callers may connect at all. An `ALLOW` policy answers both. It also changes the default for the workload: once one `ALLOW` policy selects the pods, every connection that no rule matches is refused. This chapter writes two `ALLOW` policies and checks each with real connections, including a port the Kubernetes Service does not list.

<!-- astrona:playground:renew -->

## Allow two ports

Start with the smallest useful policy. It selects the `tcp-echo` pods and allows connections to ports `9000` and `9001` from any caller. Save this as `authorizationpolicy-tcp-echo-allow-ports.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
  - to:
    - operation:
        ports: ["9000", "9001"]
```

The `ports` values are strings. The rule has a `to` part and no `from` part, so any caller matches. Apply it:

```sh
kubectl apply -f authorizationpolicy-tcp-echo-allow-ports.yaml
```

Wait up to about a minute, then connect to each port:

```sh
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
tcp_from shuttle $ECHO_IP 9002
```

The first two lines print `allowed`. The third prints `refused`, although the policy never mentions port `9002`. This is default-deny: the policy selects the workload, port `9002` fits no rule, and the sidecar proxy closes the connection. The pass-through filter chain, which handles the pod IP path, is under the same policy as the ports the Service lists.

That last point matters for security. A Service lists only the ports you want clients to use, but the pod listens on whatever the container opens. An `ALLOW` policy closes the unlisted ports as well, so a forgotten listener is not reachable.

## Allow one caller

Ports tell the proxy where a connection goes. The `from` part tells it who connects. Replace the policy with one that allows only the `shuttle`, and only on port `9000`. Save this as `authorizationpolicy-tcp-allow-shuttle.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/shuttle"]
    to:
    - operation:
        ports: ["9000"]
```

The object keeps the name `tcp-policy`, so `kubectl apply` replaces the previous version. Inside one rule, the `from` part and the `to` part must both match. The principal is written without the `spiffe://` prefix. Apply it and test both clients:

```sh
kubectl apply -f authorizationpolicy-tcp-allow-shuttle.yaml
tcp_from shuttle tcp-echo 9000
tcp_from relay tcp-echo 9000
tcp_from shuttle tcp-echo 9001
```

Only the first line prints `allowed`. The `relay` has a valid certificate, but its identity is `cluster.local/ns/starfleet/sa/relay`, which the rule does not name. The shuttle is refused on `9001` because the rule names only `9000`.

## See the refusal on the receiving side

A refused TCP connection has no status code, so the caller only sees a closed connection. The receiving proxy records the refusal. Read the `tcp-echo` proxy log after the refused calls:

```sh
kubectl logs -n starfleet -l app=tcp-echo -c istio-proxy --since=2m | tail -5
```

A refused connection leaves a line in this log, and the line shows the connection closed without a reply from the server. The caller cannot tell a policy refusal from a server that is down, so check the receiving side first.

You can also ask what `istioctl` knows about the workload. Run `istioctl x authz check deploy/tcp-echo -n starfleet` to list the policies the proxy loaded. The command is experimental, and its output format can change between versions, so use it to confirm that the policy arrived and not to prove behaviour. A real connection is the proof.

Two kinds of rule now work for you. A rule with only `to.operation.ports` limits a workload to named ports for every caller. A rule with `from.source.principals` limits it to named callers. Both leave one question open: what happens when a rule uses a field that a TCP connection does not have, such as `methods`?

## Common pitfalls

> [!WARNING]
> - **`ports` written as a number.** The field takes strings: `["9000"]`, not `[9000]`.
> - **A `spiffe://` prefix in `principals`.** Istio adds the prefix itself, so the rule never matches.
> - **Testing only from one client.** A policy that allows the shuttle can look correct until a second identity connects. Test an allowed and a refused caller.
> - **Forgetting the pod-IP path.** A port the Service does not list is still open without an `ALLOW` policy.
