# Overview: Authorize TCP Traffic (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Istio
and the Starfleet, and then waits. There is no task, no `astrona submit` and
no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only).
  `istiod` is Istio's control plane: it sends every proxy its configuration
  and issues the workload certificates.
- Mesh-wide **access logs**, so every proxy writes one line per request.
- Namespace **`starfleet`**, labelled `istio-injection=enabled`, with the
  Starfleet sample app (`bridge`, `cargo`, `scout`, `navcom`), `probe` and
  `fortio`.
- **`tcp-echo`**, a plain TCP server. It listens on ports `9000`, `9001` and
  `9002` and answers with `hello` followed by the text you send. Its Service
  declares only `9000` and `9001`. Port `9002` is reachable by pod IP only.
- **`shuttle`**, a client pod with `nc` and `curl`. Its identity is
  `cluster.local/ns/starfleet/sa/shuttle`.
- **`relay`**, a second client pod with its own service account, so its
  identity is `cluster.local/ns/starfleet/sa/relay`.
- A **`PeerAuthentication` named `default` in `starfleet`, mode `STRICT`**, so
  callers are verified by mTLS and a policy can trust their identity.
- Namespace **`outpost`** without injection, with the **`drifter`**: a client
  with no sidecar proxy and no certificate.
- **No `AuthorizationPolicy`.** Everything inside `starfleet` is allowed.

## Helpers

Paste these once in each new terminal:

```sh
tcp_from() { out=$(kubectl exec -n starfleet deploy/$1 -c $1 -- sh -c "echo 'port $3' | nc -w 3 $2 $3" 2>&1); case "$out" in *hello*) echo "$1 -> $2:$3 allowed ($out)";; *) echo "$1 -> $2:$3 refused";; esac; }
ECHO_IP=$(kubectl get pod -n starfleet -l app=tcp-echo -o jsonpath='{.items[0].status.podIP}')
```

`tcp_from shuttle tcp-echo 9000` sends the text `port 9000` from the shuttle
to the Service on port 9000. The helper prints `allowed` when the reply contains `hello`, and `refused`
when no reply comes back because the sidecar proxy closed the connection.
`tcp_from shuttle $ECHO_IP 9002` reaches port 9002 by pod IP.

Wait up to about a minute after every `kubectl apply` before you trust a test.
A connection that was already open keeps the old rules for a while.

## Things to try

- Apply `examples/01-tcp-policies/01-authorizationpolicy-tcp-echo-allow-ports.yaml`
  and test ports 9000, 9001 and the pod IP on 9002.
- Replace it with the identity example and call from `shuttle` and from `relay`.
- Apply each file in `examples/01-tcp-policies/cases/` one at a time and
  predict the result for 9000 and 9001 before you test.
- Change the `DENY` case so it names only `ports: ["9001"]`.
- Look at the `tcp-echo` sidecar proxy log and find the connection you refused.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old one
  is still there: `astrona destroy ats-015-playground-020-03`, then run again.
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-020-03`.
- A pod in `starfleet` shows `1/1` instead of `2/2`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.

## When you're done

```sh
astrona destroy ats-015-playground-020-03
```

## Practice tasks

Two exam-style tasks. Paste the helpers first. Wait up to about a minute after
each apply before you trust a test.

### Task 1: only the shuttle may reach port 9000

> In namespace `starfleet`, only the `shuttle` may open connections to port
> `9000` of `tcp-echo`. The `relay` must be refused on every port.

<details><summary>Solution</summary>

An `ALLOW` policy with a `from` part naming the shuttle's principal and a `to`
part naming the port. Once one `ALLOW` policy selects `tcp-echo`, everything
that no rule matches is refused.

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-allow-shuttle
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

Apply it with `kubectl apply -f`, then run `tcp_from shuttle tcp-echo 9000`
(`allowed`) and `tcp_from relay tcp-echo 9000` (`refused`).

</details>

### Task 2: close port 9001 for everyone without touching the ALLOW policy

> Keep the policy from task 1. Add one more policy so that port `9001` is
> refused for every caller, even if someone later allows it.

<details><summary>Solution</summary>

A `DENY` policy scoped with `ports` only. A `DENY` rule has no HTTP-only
fields here, so Istio reads it as written.

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-deny-9001
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: DENY
  rules:
  - to:
    - operation:
        ports: ["9001"]
```

Apply it and run `tcp_from shuttle tcp-echo 9001`. The sidecar proxy closes the
connection, and no `hello` comes back.

</details>
