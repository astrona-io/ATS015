# One Path, One Network

Astronaut, a block-list keeps a few addresses out. The opposite request is just as common: "only the office may reach the admin pages". This part writes that rule without closing the rest of the gate, then shows how to read back everything that decides an address rule, and finally what an address is really worth as a control.

## Open one path to one network only

The bridge's API on `/api/v1/products` is the surface to protect here. Only the office network, `203.0.113.0/24`, may reach it. Everyone may still open `/productpage`.

### Turn "only X" into a `DENY`

"Only the office may reach this path" is the same as "refuse this path when the client is **not** the office". Written that way, it is a `DENY`, and a `DENY` leaves every signal it does not name alone.

The first instinct is often an `ALLOW` policy with the path and the office range. It lets the office in, but it also refuses `/productpage` for everyone: once an `ALLOW` policy selects the gateway, every signal that matches none of its rules is refused.

<!-- astrona:playground:renew -->

The rule needs the gateway to trust one relay, so `istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops` must print `"xffNumTrustedHops": 1`. Save this as `authorizationpolicy-gateway-api-office-only.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-api-office-only
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - to:
    - operation:
        hosts: ["starfleet.example.com"]
        paths: ["/api/v1/products*"]
    from:
    - source:
        notRemoteIpBlocks: ["203.0.113.0/24"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-gateway-api-office-only.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/gateway-api-office-only created
```

The warning is normal for a `DENY` rule with HTTP fields (a host and a path). On a plain TCP channel those fields cannot be read, so Istio would refuse everything there. The gate only speaks HTTP, so nothing extra is blocked.

Read the rule like this: `to` and `from` in the same rule must **both** match. The signal goes to the API on this host, **and** its client is outside the office range. Only then is it refused.

### Check every corner

Wait about a minute, so the gate gets its new orders. Then check the result. Test the office and an outsider on the API, and an outsider on the page:

```sh
gate_status /api/v1/products 203.0.113.7
gate_status /api/v1/products 10.1.2.3
gate_status /productpage 10.1.2.3
```

```text
200
403
200
```

The office gets the API, the outsider does not, and the page stays open for everyone. Three signals, three corners of the rule. Testing only one of them would not tell a correct rule from one that closes everything.

## Read back what is in force

An address rule can be wrong in three places: the policy, the trusted relay setting, and your idea of which address arrives. Only the first one is visible in the YAML you wrote. Check all three.

### Three questions, three places

```sh
kubectl get authorizationpolicy -A
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}'
```

```text
NAMESPACE       NAME                      ACTION   AGE
istio-ingress   gateway-api-office-only   DENY     60s
defaultConfig:
  discoveryAddress: istiod.istio-system.svc:15012
  gatewayTopology:
    numTrustedProxies: 1
defaultProviders:
  metrics:
  - prometheus
enablePrometheusMerge: true
rootNamespace: istio-system
trustDomain: cluster.local
```

The first command lists every policy on every planet. On a shared gate, that includes policies someone else wrote, and a policy on the wrong planet shows up here too. The second shows the mesh-wide setting that `istiod` holds. It is only a setting: the proof that the gateway uses it is still `xffNumTrustedHops` in the gateway's listener.

The third question is "which address did the gate see?", and only the flight log answers it:

```sh
gate_log 3
```

```text
[2026-10-09T11:12:59.501Z] "GET /api/v1/products HTTP/1.1" 200 - via_upstream - "-" 0 395 19 18 "203.0.113.7,10.244.0.18" "curl/8.7.1" "ac5f0a1f-ab9c-4efa-a78c-443d474453e8" "starfleet.example.com" "10.244.0.12:9080" outbound|9080||bridge.starfleet.svc.cluster.local 10.244.0.18:48876 127.0.0.1:80 203.0.113.7:0 - -
[2026-10-09T11:12:59.536Z] "GET /api/v1/products HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-ingress]-policy[gateway-api-office-only]-rule[0]] - "-" 0 19 0 - "10.1.2.3,10.244.0.18" "curl/8.7.1" "12a6498f-79e9-4c95-9452-76720468a51b" "starfleet.example.com" "-" outbound|9080||bridge.starfleet.svc.cluster.local - 127.0.0.1:80 10.1.2.3:0 - -
[2026-10-09T11:12:59.550Z] "GET /productpage HTTP/1.1" 200 - via_upstream - "-" 0 15068 146 145 "10.1.2.3,10.244.0.18" "curl/8.7.1" "e1224188-0e01-4023-8bfb-9c6ca68a250d" "starfleet.example.com" "10.244.0.12:9080" outbound|9080||bridge.starfleet.svc.cluster.local 10.244.0.18:60878 127.0.0.1:80 10.1.2.3:0 - -
```

Each line shows the decision and the client address together: `203.0.113.7:0` got the API, `10.1.2.3:0` did not, and `10.1.2.3:0` still got the page. Compare that address with your range, and most surprises explain themselves in one line.

### The order to check in

When a gate rule does not do what you expect, go through it in this order:

1. **Does the policy exist, and does it select the gateway?** `kubectl get authorizationpolicy -A`, then the gateway pod's labels and namespace.
2. **Does the gate trust the right number of relays?** `xffNumTrustedHops` in the gateway's listener.
3. **Which address did the gate see?** The last address on the flight log line.
4. **Is that address inside the range you wrote?** Simple arithmetic on the CIDR.

Steps 3 and 4 catch most mistakes. Step 1 catches the rest.

## What an address is worth

Addresses are a coarse control. Knowing their limits tells you where they belong in a design.

### Good at shrinking the crowd

An address rule is good at **reducing who can even try**: an admin path only from the office, a known attacking network blocked, a partner limited to the addresses they publish. It costs almost nothing per signal, and it cuts the crowd at the gate.

### Weak as an identity

An address is not a person or a program. Many people share one address behind a home or office router. Cloud providers hand addresses to new owners. VPNs and proxies lend addresses to anyone. And `remoteIpBlocks` reads a header that is only trustworthy with the right `numTrustedProxies`. "This signal came from 203.0.113.7" means "it came from that network", never "it came from Alice".

| Control | It proves | Strength | Where it works |
| --- | --- | --- | --- |
| Source address | the network the signal came from | weak, coarse | the gate |
| Client certificate | the calling system | strong | the gate |
| JSON Web Token (JWT) | the end user and their roles | strong, expires | the gate or the ship |
| Mesh identity | the calling workload | strong | inside the mesh |

So use the address rule as the first, cheap layer, and put a real identity check behind it. For the admin path above, that means the right network **and** a valid token. Neither alone is enough; together they are a real barrier.

### Clean up

Remove the policy:

```sh
kubectl delete -f authorizationpolicy-gateway-api-office-only.yaml
```

## Common pitfalls

> [!WARNING]
> - **"Only X" written as `ALLOW`.** An `ALLOW` on the gate refuses every signal that matches none of its rules, on every host. Write "only X may reach this path" as a `DENY` for the path with `notRemoteIpBlocks`.
> - **`to` and `from` in separate rules.** Two rules are two separate reasons to refuse. Put the path and the range in the **same** rule so both must match.
> - **Testing one corner.** Test the allowed network, an outsider on the protected path, and an outsider on an open path.
> - **Trusting the YAML.** Read back the policies with `kubectl get authorizationpolicy -A`, the trusted relays with `xffNumTrustedHops`, and the address in the flight log.
> - **An address as the only lock.** Addresses are shared, reassigned and borrowed. Put a real identity check behind them.

> *"Only this network may reach this path" is a `DENY` on the path for everyone outside the network, and the flight log is the only place where the address and the decision meet.*

## Your mission: Open One Path To One Network

You can now open one path to one network at the arrival gate, keep the rest of the gate open, and read back every piece that decides the result. Now prove it in a graded mission: on the Starfleet's gate, only the office range may reach the bridge's API, and nobody may lose access to the page.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-050-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-02
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-050-01-02
astrona start ats-015-playground-050-01
```
