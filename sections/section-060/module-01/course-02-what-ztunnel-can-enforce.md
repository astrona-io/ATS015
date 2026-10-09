# What ztunnel Can Enforce

In ambient mode, ztunnel is the per-node proxy that carries every connection between pods. It ends the HBONE tunnel (HTTP-Based Overlay Network Environment, the mutual TLS tunnel between proxies), so it sees the caller's certificate and the connection's addresses and ports. It sees nothing of the request inside. That one fact splits the fields of an `AuthorizationPolicy` into two groups: the ones ztunnel can check on its own, and the ones it cannot.

This chapter is about the first group. You write a rule that ztunnel enforces with no waypoint at all, test it from two callers, and then look closely at what a refusal from ztunnel looks like. It does not look like the `403` you may know from sidecar mode, and reading it correctly saves a lot of time.

## Allow only `bridge` to reach `cargo`

Start with a real rule. The `cargo` backend should only accept connections from the `bridge` frontend, and every other workload, including your `shuttle` test client, should be refused. The rule names the identity of `bridge`, which comes from its service account, `starfleet-bridge`.

<!-- astrona:playground:renew -->

Save this as `authorizationpolicy-cargo-l4.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cargo-l4
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: cargo
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-bridge
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-cargo-l4.yaml
```

```text
authorizationpolicy.security.istio.io/cargo-l4 created
```

The policy uses a label `selector`, exactly as in sidecar mode. It points at the `cargo` pods, and the ztunnel in front of those pods enforces it.

To see the rule at work, send a request from the `shuttle` pod straight to `cargo`:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://cargo:9080/details/0
```

```text
000
command terminated with exit code 56
```

`curl` prints `000` because no HTTP answer came back at all, and `kubectl exec` adds the line about exit code 56: `curl` saw the connection being cut. If you still get `200`, wait about a minute and send the request again. A new rule takes up to a minute to reach live traffic, because connections that are already open keep the old rule.

The `shuttle` pod runs as the service account `shuttle`, not `starfleet-bridge`, so it is refused. And no waypoint exists. ztunnel enforced the rule on its own, because everything the rule needs was on the tunnel: the caller's identity.

A refusal alone does not prove the rule is right, because a broken rule could refuse everyone. So check the allowed caller too. The product API of `bridge` at `/api/v1/products/0` calls `cargo` behind the scenes, with the identity of `bridge`:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code}\n" http://bridge:9080/api/v1/products/0
```

```text
200
```

`200` means `bridge` still reaches `cargo`. The same `cargo` pod refused one caller and served another, based only on who was calling.

## The L4 field set

The test worked because a `principals` rule needs nothing from inside the request. It is an **L4** rule (layer 4, the connection), not an **L7** rule (layer 7, the HTTP request inside the connection). Other fields are not so lucky. Here is the full list of what ztunnel can and cannot check:

| Field | ztunnel can enforce it | Why |
| --- | --- | --- |
| `from.source.principals` | **yes** | read from the caller's certificate on the tunnel |
| `from.source.namespaces` | **yes** | part of the same identity |
| `from.source.ipBlocks` | **yes** | the connection's source address |
| `to.operation.ports` | **yes** | the destination port of the connection |
| `to.operation.methods` | no | needs the HTTP request |
| `to.operation.paths` | no | needs the HTTP request |
| `to.operation.hosts` | no | needs the `Host` header |
| `from.source.requestPrincipals` | no | needs a checked JSON Web Token (JWT) |
| `when` on `request.headers[...]` or `request.auth.*` | no | needs the HTTP request |

The general rule is simple. If you can decide it from the connection alone (who, from where, to which port), ztunnel can do it. If you must read the HTTP request, you need a waypoint.

One detail about `ports` catches people out. ztunnel sees the port the connection reaches on the pod. For the `probe`, that is the container port `8080`, not the Service port `8000`.

## An L4 denial is a refused connection

Now look at that `000` again. In sidecar mode a refused request always got a `403`, because the proxy read the request and wrote an HTTP answer. ztunnel has no HTTP layer, so it cannot write an answer. It closes the **connection** instead.

```mermaid
flowchart TB
    R["request arrives"] --> Q{"who refuses?"}
    Q -->|"ztunnel, L4"| C["connection reset: curl shows 000"]
    Q -->|"waypoint, L7"| F["HTTP 403 RBAC: access denied"]
```

The diagram shows the two ways an ambient namespace says no. ztunnel can only drop the connection, so `curl` prints `000`. A waypoint reads HTTP, so it answers with a `403` and the text `RBAC: access denied` (RBAC is role-based access control, Envoy's name for its authorization filter).

That gives you a quick way to read failures in an ambient namespace:

| What the caller sees | Who refused | Layer |
| --- | --- | --- |
| `000`, connection reset | ztunnel | L4 |
| `403` | a waypoint | L7 |
| any other answer | nobody: the app answered | none |

The status code tells you which component decided before you read a single policy. There is one side effect: **a caller cannot tell an L4 refusal from a pod that is down.** Both look like a broken connection. If a caller must know "you are not allowed" from "try later", it needs an L7 rule on a waypoint, which answers `403`.

> [!TIP]
> In an ambient namespace, read the status code before you read any policy. `000` means ztunnel refused the connection, `403` means a waypoint refused the request, and anything else came from the app.

Because the caller cannot tell a refusal from an outage, you need proof from the other side. ztunnel writes a log line for every connection it closes. Read the last lines from the ztunnel pods and keep the ones about refusals:

```sh
kubectl logs -n istio-system ds/ztunnel --tail=20 | grep -i "policy"
```

```text
2026-10-09T11:39:41.876395Z	error	access	connection complete	src.addr=10.244.0.14:58564 src.workload="shuttle-7b5db664c-hmlqb" src.namespace="starfleet" src.identity="spiffe://cluster.local/ns/starfleet/sa/shuttle" dst.addr=10.244.0.8:15008 dst.hbone_addr=10.244.0.8:9080 dst.service="cargo.starfleet.svc.cluster.local" dst.workload="cargo-v1-6f787f8bd5-h2bpn" dst.namespace="starfleet" dst.identity="spiffe://cluster.local/ns/starfleet/sa/starfleet-cargo" direction="inbound" bytes_sent=0 bytes_recv=0 duration="0ms" error="connection closed due to policy rejection: allow policies exist, but none allowed"
```

The line names the caller's identity (`src.identity`), the pod it tried to reach (`dst.workload`) and the reason (`error=...`). The words "allow policies exist, but none allowed" mean an `ALLOW` policy selects `cargo` and no rule in it matched `shuttle`. This is how you prove an L4 refusal came from a policy, and not from a pod that is down. If the playground has more than one node, `ds/ztunnel` reads only one ztunnel pod; this playground has one node.

You now know what ztunnel can enforce on its own: everything you can decide from the connection, identity included. You also know how its refusal looks, a closed connection with `000`, and where to find the log line that proves it. The open question is the other half of the table: what happens when a policy asks for a field that ztunnel cannot read?

## Common pitfalls

> [!WARNING]
> - **Expecting a `403` from an L4 refusal.** ztunnel closes the connection. `curl` shows `000` and exits with an error.
> - **Thinking identity needs a waypoint.** `principals` and `namespaces` come from the certificate on the tunnel. ztunnel enforces them alone.
> - **Using the Service port in a `ports` rule.** ztunnel sees the pod's port, for example `8080` for the probe, not `8000`.
> - **Reading a policy as enforced because it exists.** In ambient mode, always ask which component enforces it.

## Your mission: Allow Callers By Identity With L4 Policy

You can now write an identity rule that ztunnel enforces with no waypoint, and read the refused connection it gives. The graded lab asks you to restrict two Starfleet workloads so that only the right callers can reach them, using L4 rules alone.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-060-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-060/module-01/labs/lab-02
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-060/module-01/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-060-01-02
astrona start ats-015-playground-060-01
```
