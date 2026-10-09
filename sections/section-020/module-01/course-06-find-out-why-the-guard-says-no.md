# Troubleshoot An Authorization Denial

Sooner or later a policy will not do what you meant. When that happens, there are only two possibilities. Either the policy reached the workload's proxy and its rules are wrong, or the policy never reached the proxy at all.

The two cases need different fixes, and `kubectl get` cannot tell them apart, because the object exists either way. This chapter shows the three tools that can: the receiving workload's access log, the proxy's configuration, and `istioctl analyze`. You will break one policy on purpose, find the fault with each tool, and fix it.

The commands below need `allow-nothing` and the four least-privilege policies (`bridge-allow-get`, `cargo-allow-bridge`, `scout-allow-bridge`, `navcom-allow-scout`) applied in your playground, and the three helper functions from the landing page.

## Read the decision in the access log

Every proxy writes one line per request into its access log. For a denied request, the line also says which policy decided. You read it on the workload that **received** the request, because that is where the check ran.

<!-- astrona:playground:renew -->

Send a request from the `shuttle` straight to `scout`, a shortcut that the least-privilege policies close. Then read the access logs of the `scout` pods:

```sh
from_shuttle http://scout:9080/reviews/0
sleep 5
kubectl logs -n starfleet -l app=scout -c istio-proxy --tail=5 | grep rbac_access_denied | tail -1
```

```text
403 403 403 <- http://scout:9080/reviews/0
[2026-10-09T07:42:04.120Z] "GET /reviews/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.11.1" "d69c9218-bfce-4d76-a568-cdd460a5f7ea" "scout:9080" "-" inbound|9080|| - 10.244.0.10:9080 10.244.0.12:33766 outbound_.9080_._.scout.starfleet.svc.cluster.local default
```

The `sleep 5` is there because the proxy writes its access log in small batches, a few seconds after the request. The line gives the answer in one field: `rbac_access_denied_matched_policy[none]`. The proxy held RBAC (role-based access control) rules, and **no** `ALLOW` rule matched this request. If a `DENY` policy had denied it, the brackets would name that policy and rule instead, for example `ns[starfleet]-policy[some-deny]-rule[0]`.

`[none]` tells you that a policy arrived. It does not tell you whether the right policy arrived. For that, you have to ask the proxy itself.

## Break one policy on purpose

The quietest failure is a `selector` that matches no pod. The object is valid, `kubectl apply` accepts it, and `kubectl` does not warn you. It is worth seeing once on purpose, so you know it when it happens by accident.

Save this as `authorizationpolicy-navcom-allow-scout.yaml`. It is the `navcom` policy with one typo, `navcomm`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-allow-scout
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcomm
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/starfleet-scout"]
    to:
    - operation:
        methods: ["GET"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-allow-scout.yaml
```

Then check the result. Wait up to about a minute and load the `bridge` page six times:

```sh
for i in 1 2 3 4 5 6; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage \
    | grep -oE 'currently unavailable|glyphicon-star' | sort -u | tr '\n' ' '; echo
done
```

```text
currently unavailable 
currently unavailable 



currently unavailable 
```

The page still loads, and the reviews are there. But the `navcom` proxy now denies every `scout` pod that asks for a rating, so the stars are replaced by an error (the page says `Ratings service is currently unavailable`). Empty lines are `scout` v1 loads, which never ask for a rating. `navcom` is covered only by `allow-nothing` again.

## Ask the proxy and istioctl

The log would only say `[none]` here, which does not explain the fault. The proxy's own configuration does. `istiod` compiles every policy into that configuration, and each rule keeps its policy's name.

The place to look is a listener: the part of Envoy's configuration that accepts connections on one port. Ask the `navcom` proxy which policies it received on its inbound listener, port `15006`, where every incoming request enters:

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
```

```text
ns[starfleet]-policy[allow-nothing]
```

Only `allow-nothing` is there; `navcom-allow-scout` is missing. The object exists, but its selector matches no pod, so `istiod` never sent it to `navcom`. No edit to its rules would help.

`istioctl analyze` finds the same fault from the other side. It runs Istio's own checks over a namespace, and it compares objects with the pods they point at:

```sh
istioctl analyze -n starfleet
```

```text
Warning [IST0127] (AuthorizationPolicy starfleet/navcom-allow-scout) No matching workloads for this resource with the following labels: app=navcomm
```

`analyze` names the policy and the label that matches nothing. It is only a warning, so the command still exits with success; read the output, not the exit code. Run it after every security change, because it catches typos before your test requests do.

To fix the fault, change `app: navcomm` back to `app: navcom` in `authorizationpolicy-navcom-allow-scout.yaml`, then apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-allow-scout.yaml
```

Then check the result. The proxy now holds the policy, and the stars come back:

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
```

```text
ns[starfleet]-policy[allow-nothing]
ns[starfleet]-policy[navcom-allow-scout]
```

Both policies are in the proxy's configuration again. Wait up to about a minute and run the page loop again: the `currently unavailable` lines are gone, and `istioctl analyze -n starfleet` reports `No validation issues found`.

## Wrong rule or missing policy

Put the three tools together, and every "the policy does nothing" case falls into one of a few groups. The table shows how to tell them apart:

| What you see | What it means | What to fix |
| --- | --- | --- |
| Policy listed by `kubectl get`, missing from `proxy-config listener` | the policy never reached the proxy | the `selector` labels, or the namespace the policy lives in |
| Policy in `proxy-config listener`, log says `matched_policy[none]` | the policy arrived, but no rule matches | the rule: the service account name, a stray `spiffe://`, the method or path |
| `000` and a reset connection, no log line with `403` | the authorization check never saw the request | `PeerAuthentication` and the caller's sidecar, not the policy |

A wrong service account is the classic "arrived but wrong" case. A rule that names `sa/bridge` instead of `sa/starfleet-bridge` is in the proxy's configuration; it simply never matches.

> [!TIP]
> On the exam, debug a denied request in this order: `kubectl get authorizationpolicy -A` (what could apply), `istioctl proxy-config listener` on the receiver (what did arrive), then the receiver's access log (which policy decided). Three commands, and you know which case you have.

In short, `kubectl get` shows what you wrote, the proxy configuration shows what arrived, and the access log shows what the proxy decided. With those three views you can tell a policy that never arrived from a rule that is wrong, and fix the right thing first.

## Common pitfalls

> [!WARNING]
> - **Editing the rules of a policy that never arrived.** If the policy is missing from the proxy's configuration, the problem is the `selector` or the namespace.
> - **Reading the caller's log.** The decision is logged by the workload that received the request.
> - **Trusting `kubectl get` as proof.** It shows the object exists, not that any proxy received it.
> - **Skipping `istioctl analyze`.** A selector that matches no pod is exactly the kind of mistake it catches.

## Your mission: Repair Broken AuthorizationPolicies

You can now read a denial in the access log, check which policies a proxy really holds, and tell a wrong rule from a policy that never arrived. In the graded lab, the Starfleet least-privilege policies are in place but the `bridge` page is broken: find and fix every fault without opening any shortcut.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-020-01
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-020-01-02
astrona start ats-015-playground-020-01
```
