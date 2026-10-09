# Find Out Why The Guard Says No

Astronaut, sooner or later a policy will not do what you meant. When that happens there are only two possibilities. Either the list reached the ship and its rules are wrong, or the list never reached the ship at all. They need different fixes, and `kubectl get` cannot tell them apart: the object exists either way.

This part shows the three tools that can: the receiving ship's flight log, the proxy's own orders, and `istioctl analyze`.

The commands below need `allow-nothing` and the four least-privilege policies (`bridge-allow-get`, `cargo-allow-bridge`, `scout-allow-bridge`, `navcom-allow-scout`) applied in your playground, and the three helpers from the module's landing page.

## Read the guard's decision in the flight log

Every proxy writes one line per signal into its flight log (the access log). For a refused signal, the line also says which list decided. You read it on the ship that **received** the signal.

### A refused shortcut

<!-- astrona:playground:renew -->

Send the shuttle straight to the scout, then read the scouts' flight logs:

```sh
from_shuttle http://scout:9080/reviews/0
sleep 5
kubectl logs -n starfleet -l app=scout -c istio-proxy --tail=5 | grep rbac_access_denied | tail -1
```

```text
403 403 403 <- http://scout:9080/reviews/0
[2026-10-09T07:42:04.120Z] "GET /reviews/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.11.1" "d69c9218-bfce-4d76-a568-cdd460a5f7ea" "scout:9080" "-" inbound|9080|| - 10.244.0.10:9080 10.244.0.12:33766 outbound_.9080_._.scout.starfleet.svc.cluster.local default
```

The `sleep 5` is there because the proxy writes its flight log in small batches, a few seconds after the signal. The line ends the story in one field: `rbac_access_denied_matched_policy[none]`. The guard held a list, and **no** `ALLOW` rule on it fitted this signal. If a `DENY` policy had refused it, the brackets would name that policy and rule instead, for example `ns[starfleet]-policy[some-deny]-rule[0]`.

`[none]` tells you the list arrived. It does not tell you whether the right list arrived. For that, ask the proxy.

## Break one list on purpose

The quietest failure is a `selector` that matches no pod. The object is valid, `kubectl apply` accepts it, and `kubectl` does not warn you. See it once on purpose, so you know it when it happens by accident.

### Misspell the selector

Save this as `authorizationpolicy-navcom-allow-scout.yaml`. It is the `navcom` list with one typo, `navcomm`:

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

Then check the result. Wait up to about a minute and load the bridge page six times:

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

The page still loads, and the reviews are there. But every scout that asks `navcom` for a rating now gets turned away, so the stars are replaced by an error (the page says `Ratings service is currently unavailable`). Empty lines are scout v1 loads, which never ask for a rating. `navcom` is covered only by `allow-nothing` again.

### Ask the proxy which lists it holds

Mission control compiles every list into the proxy's orders, and each rule keeps its policy's name. Ask `navcom`'s proxy which policies it received on its inbound listener (port `15006`, where every incoming signal enters):

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
```

```text
ns[starfleet]-policy[allow-nothing]
```

Only `allow-nothing` is there; `navcom-allow-scout` is missing. The object exists, but its selector matches no pod, so `istiod` never sent it to `navcom`. No edit to its rules would help.

### Ask istioctl analyze

`istioctl analyze` runs Istio's own checks over a namespace, and it compares objects with the pods they point at:

```sh
istioctl analyze -n starfleet
```

```text
Warning [IST0127] (AuthorizationPolicy starfleet/navcom-allow-scout) No matching workloads for this resource with the following labels: app=navcomm
```

`analyze` names the policy and the label that matches nothing. It is only a warning, so the command still exits with success; read the output, not the exit code. Run it after every security change: it catches typos before your signals do.

### Fix the selector

Change `app: navcomm` back to `app: navcom` in `authorizationpolicy-navcom-allow-scout.yaml`, then apply it:

```sh
kubectl apply -f authorizationpolicy-navcom-allow-scout.yaml
```

Then check the result. The proxy now holds the list, and the stars come back:

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
```

```text
ns[starfleet]-policy[allow-nothing]
ns[starfleet]-policy[navcom-allow-scout]
```

Both lists are in the proxy's orders again. Wait up to about a minute and run the page loop again: the `currently unavailable` lines are gone, and `istioctl analyze -n starfleet` reports `No validation issues found`.

## Wrong rule or missing list

Put the three tools together and every "the policy does nothing" case falls into one of two boxes. The table shows how to tell them apart.

### Two failures, two fixes

| What you see | What it means | What to fix |
| --- | --- | --- |
| Policy listed by `kubectl get`, missing from `proxy-config listener` | the list never reached the ship | the `selector` labels, or the namespace the policy lives in |
| Policy in `proxy-config listener`, log says `matched_policy[none]` | the list arrived, but no rule fits | the rule: the service account name, a stray `spiffe://`, the method or path |
| `000` and a reset connection, no log line with `403` | the guard never saw the signal | `PeerAuthentication` and the caller's sidecar, not the policy |

A wrong service account is the classic "arrived but wrong" case. A rule that names `sa/bridge` instead of `sa/starfleet-bridge` is in the proxy's orders, it simply never matches.

> [!TIP]
> On the exam, debug a refused signal in this order: `kubectl get authorizationpolicy -A` (what could apply), `istioctl proxy-config listener` on the receiver (what did arrive), then the receiver's flight log (which list decided). Three commands, and you know which box you are in.

## Common pitfalls

> [!WARNING]
> - **Editing the rules of a list that never arrived.** If the policy is missing from the proxy's orders, the problem is the `selector` or the namespace.
> - **Reading the caller's log.** The decision is logged by the ship that received the signal.
> - **Trusting `kubectl get` as proof.** It shows the object exists, not that any proxy received it.
> - **Skipping `istioctl analyze`.** A selector that matches no pod is exactly the kind of mistake it catches.

> *`kubectl get` shows what you wrote. The proxy's orders show what arrived. The flight log shows what the guard decided.*

## Your mission: Repair The Fleet's Guest Lists

You can now read a refusal in the flight log, check which lists a proxy really holds, and tell a wrong rule from a list that never arrived. Now prove it in a graded mission: the Starfleet's least-privilege lists are in place, but the bridge page is broken, and you have to find and fix every fault without opening any shortcut.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-020-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-02
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-020-01-02
astrona start ats-015-playground-020-01
```
