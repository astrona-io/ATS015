# Summary

In ambient mode, pods run with no sidecar proxy, and two other components enforce `AuthorizationPolicy`. ztunnel checks the connection (L4), and a waypoint checks the HTTP request (L7). This module followed one namespace from no rules to rules at both layers, and showed how to tell a policy that works from one that only exists.

## What you learned

ztunnel runs once on every node. It carries each pod's traffic through HBONE, an HTTP/2 `CONNECT` tunnel inside mutual TLS on port `15008`, so it always knows the caller's identity. It never reads HTTP. istio-cni sends a pod's traffic to ztunnel, and the label `istio.io/dataplane-mode=ambient` on a namespace enrols the pods already running, with no restart and no extra container. `istioctl ztunnel-config workload` shows `PROTOCOL: HBONE` for an enrolled pod.

Because identity travels on the tunnel, ztunnel can enforce `principals`, `namespaces`, `ipBlocks` and `ports` on its own, with a `selector` and no waypoint. It cannot enforce `methods`, `paths`, `hosts`, `requestPrincipals` or `when` conditions on the request. When ztunnel refuses, it closes the connection, so `curl` shows `000`. A waypoint answers with an HTTP `403`. The ztunnel log names the caller, the target and the reason for each refused connection.

An L7 rule with no waypoint is never the rule you wrote. Attached with `targetRefs`, it is accepted, listed and ignored, and its `WaypointAccepted` status condition is `False`. Attached with a `selector`, it goes to ztunnel, which drops the rule it cannot check, so the `ALLOW` matches nothing and every caller is refused.

A waypoint needs two steps: `istioctl waypoint apply` creates it, and the label `istio.io/use-waypoint` on a namespace or Service sends traffic through it. With both in place, the same `targetRefs` policy starts to work. Behind a waypoint, the destination's ztunnel sees the waypoint's identity, so a pod-level rule that allows only the original caller refuses everyone.

To find which component holds a rule, compare `istioctl ztunnel-config policy` with `kubectl get authorizationpolicy`, and read the waypoint's listeners and access log. Everything else stays as in sidecar mode: identity, policy structure, evaluation order and edge TLS. The key facts to remember are these:

- Identity, namespace, IP and port rules work at ztunnel with a `selector`.
- Method, path, header and token rules need a waypoint, `targetRefs` and the `istio.io/use-waypoint` label.
- `000` means ztunnel refused; `403` means a waypoint refused.
- When a policy does nothing, ask: does it exist, does a component hold it, does it match?

In short: ztunnel enforces who may connect, a waypoint enforces what they may ask, and a rule that neither of them holds does nothing.

<!-- astrona:playground:destroy -->
