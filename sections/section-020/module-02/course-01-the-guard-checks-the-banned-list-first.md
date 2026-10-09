# DENY Is Checked Before ALLOW

When several `AuthorizationPolicy` resources select the same pod, which one decides? The sidecar proxy does not weigh them all at once. It checks them one group after another, in a fixed order, and it may stop early. Almost every question about `DENY` is answered by that order, so it is worth learning before you write a single `DENY` policy.

This chapter walks through the order, then puts a `DENY` policy on the `probe` workload. You will see what it blocks, what it lets through, and the line the sidecar proxy writes to its access log when it says no.

## Three actions, one fixed order

An `AuthorizationPolicy` has an `action`. The sidecar proxy sorts all policies that select a pod into three groups by that action, and it checks the groups in the same order for every request. The check runs in the sidecar proxy (Envoy) of the pod that **receives** the request. The sidecar proxy is a proxy container that Istio adds to each pod, and all traffic of the pod passes through it. For each request it walks these steps:

```mermaid
flowchart TB
    S["request reaches the sidecar"] --> C{"CUSTOM policy"}
    C -->|"says no"| D1["403"]
    C -->|"says yes, or none"| D{"DENY policy"}
    D -->|"a rule fits"| D2["403"]
    D -->|"nothing fits"| A{"ALLOW policies"}
    A -->|"none select this pod"| OK1["allowed"]
    A -->|"one rule fits"| OK2["allowed"]
    A -->|"no rule fits"| D3["403"]
```

The diagram shows the sidecar proxy asking an external authorization service first (`CUSTOM`), then checking `DENY` policies, and only then `ALLOW` policies.

Notice that the first two steps can only ever say no. When a `CUSTOM` policy rejects a request, or a `DENY` rule fits it, the decision **ends**, and the sidecar proxy does not check the rest. So a `DENY` does not cast a vote that an `ALLOW` can outweigh. It stops the walk before the `ALLOW` policies are even looked at.

The first step needs a word of its own. `CUSTOM` hands the decision to an outside authorization service, and it only works when an administrator has set up that service as an extension provider in the mesh configuration. You will rarely write one, but you should know where it sits in the order.

There is also no "most specific rule wins" here. The sidecar proxy does not score rules or compare how narrow they are. It walks the steps, and the first final answer is the answer.

## A workload with only a DENY policy

With the order in mind, you can put one `DENY` policy on the probe and nothing else. The result surprises many people, so predict it before you run the check.

<!-- astrona:playground:renew -->

Start by confirming that the probe answers both paths you will use. Send three requests to each from the shuttle:

```sh
from_shuttle $PROBE/get
from_shuttle $PROBE/status/200
```

```text
200 200 200 <- shuttle http://probe:8000/get
200 200 200 <- shuttle http://probe:8000/status/200
```

No policy exists yet, so the sidecar proxy lets everything in. Next comes a policy that denies every path under `/status/` on the probe, for every caller.

Save this as `authorizationpolicy-probe-deny-status.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-status
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - to:
    - operation:
        paths:
        - /status/*
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-deny-status.yaml
```

```text
Warning: configured AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP attributes in a DENY rule; it is recommended to explicitly specify the port
authorizationpolicy.security.istio.io/probe-deny-status created
```

The policy is created. The warning comes from `istiod`, Istio's control plane, which checks every policy you apply and sends the configuration to every proxy. We come back to it in a moment.

Wait up to about a minute, then check the result from both callers:

```sh
from_shuttle $PROBE/get
from_shuttle $PROBE/status/200
from_fortio $PROBE/status/200
from_fortio $PROBE/get
```

```text
200 200 200 <- shuttle http://probe:8000/get
403 403 403 <- shuttle http://probe:8000/status/200
Code 403
Code 200
```

The denied path is closed for both callers, because the rule has no `from` part and so fits every caller. And `/get` still answers, for both. No `ALLOW` policy selects the probe, so the sidecar proxy's last step says "no `ALLOW` policy selects this pod: allowed".

Now back to the warning from `kubectl apply`. The rule checks HTTP paths, but a plain TCP port (a port that carries raw bytes, not HTTP requests) has no paths to check. On such ports the sidecar proxy cannot tell what fits, so it blocks everything there to be safe. That does no harm here, because the probe only speaks HTTP. On a workload that also has a TCP port, add `ports` to the rule's `operation`, as the warning suggests.

The general rule behind this test is that adding a `DENY` does **not** turn on default-deny. Only an `ALLOW` policy does that. Side by side, the four cases look like this:

| The pod is selected by... | Result |
| --- | --- |
| no policy | everything allowed |
| only `DENY` policies | everything allowed **except** what they match |
| at least one `ALLOW` policy | only what an `ALLOW` rule matches |
| both | a `DENY` match is refused at once; the rest is decided by the `ALLOW` policies |

## Read the access log

A refusal raises the next question: which policy did it? The caller only sees a short response. The sidecar proxy on the receiving pod writes down why it said no, and that log line is how you find the policy.

Send one denied request and print its body, then read the access log line for it from the probe's sidecar proxy:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s $PROBE/status/200; echo
probe_guard_log status/200
```

```text
RBAC: access denied
[2026-10-09T08:05:55.932Z] "GET /status/200 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[starfleet]-policy[probe-deny-status]-rule[0]] - "-" 0 19 0 - "-" "curl/8.11.1" "66146f25-bad9-438d-bbe8-c08ceb51be1e" "probe:8000" "-" inbound|8080|| - 10.244.0.14:8080 10.244.0.12:54616 outbound_.8000_._.probe.starfleet.svc.cluster.local default
```

The body `RBAC: access denied` comes from the probe's sidecar proxy, not from the probe app. RBAC stands for role-based access control, the name of the Envoy filter that does the checking. The log line names the namespace, the policy and the rule number (counted from `0`) that fit. So a `403` with `RBAC: access denied` always means an `AuthorizationPolicy`, and the receiving pod's access log tells you which one.

You now know the order the sidecar proxy follows: `CUSTOM`, then `DENY`, then `ALLOW`, with a `DENY` match ending the decision. A workload with only `DENY` policies stays open for everything they do not match, and the access log names the policy behind each refusal. The open question is what happens when an `ALLOW` policy and a `DENY` policy both fit the same request.

## Common pitfalls

> [!WARNING]
> - **Ignoring the TCP port warning.** A `DENY` with only HTTP fields blocks every plain TCP port on the pods it selects. Add `ports` if the workload has one.
> - **Expecting a `DENY` to lock down the rest of the workload.** A workload with only `DENY` policies still allows everything they do not match.
> - **Thinking the sidecar proxy checks policies in the order you wrote them.** It groups them by action. Within the `DENY` group, any match ends the decision.
> - **Looking for the reason in the caller's log.** The check runs in the receiving pod's sidecar proxy. Read that pod's `istio-proxy` log.
> - **Testing straight after `kubectl apply`.** Old connections keep the old rules for a while. Wait up to about a minute; a mix like `200 403 403` means you tested too early.
