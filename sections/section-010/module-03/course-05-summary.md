# Summary

Switching a namespace to `STRICT` mTLS (mutual TLS) takes one line of YAML. Doing it without cutting off a client takes a procedure: count, write down, move the clients, measure again, and only then switch. This module walked through that procedure from the first count to the final switch.

## What you learned

The evidence lives on the **receiving** workload's sidecar proxy. Every proxy counts its requests in `istio_requests_total`, and the label `connection_security_policy` says how each one arrived: `mutual_tls` for mTLS, `none` for plain text. Only the receiver sees clients you did not know about. A `none` request with `source_workload="unknown"` comes from a client outside the mesh, and the receiving proxy's access log gives that client's address. A counter only proves the past, so measure longer than your slowest regular client, and remember that counters only go up and a pod restart wipes them.

Before you change the mode, write it down. With no `PeerAuthentication`, a namespace runs `PERMISSIVE` by default. Saving that as a `default` policy makes the choice visible, and the same file is your rollback. A `STRICT` refusal is a connection reset (`000`, curl exit code 56), not an HTTP error. `istiod` pushes each change to the running proxies, so both the break and the fix take seconds, at most about a minute, with no restart.

Moving a client into the mesh means giving it a sidecar proxy. Injection is done by a mutating admission webhook that runs only when a pod is created, so a namespace label changes nothing for running pods. The restart is the real migration step, and a bare pod with no controller does not come back. The new pod keeps its identity, because identity comes from the namespace and service account. After the move, check that the `none` count stopped going up, not that it is zero.

The switch itself is one `default` policy with `mode: STRICT`. Prove it with real requests and with `istioctl x describe pod`, because successful requests alone do not show which policy applies. A client can still break after the switch even with a sidecar. The key facts to remember are these:

- Connection reset (`000`, exit code 56): the server is `STRICT` and the client has no sidecar.
- `503` with the flag `UC` in the client's access log: the server is `STRICT` and a client `DestinationRule` has `tls.mode: DISABLE`.
- Safe order: `PERMISSIVE` first, check every client, then `STRICT`. To undo, switch back to `PERMISSIVE` before you remove any sidecar.
- A client that can never use mTLS can keep one port open with `portLevelMtls` in a policy with a `selector`, keyed by the container port.

In short: the switch is ten seconds of typing, and the procedure around it is what makes those ten seconds safe.

<!-- astrona:playground:destroy -->
