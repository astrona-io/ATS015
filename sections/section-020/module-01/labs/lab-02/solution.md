# Solution Walkthrough

The lockdown itself was right. Two policies had one wrong value each: one named a caller that does not exist, and one selected a label that no pod has. The first reached its proxy and never matched. The second never reached its proxy at all.

---

## Step 1: See the failure

Load the `bridge` page and look for errors and stars:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage \
  | grep -oE 'product reviews are currently unavailable|Ratings service is currently unavailable|glyphicon-star' | sort | uniq -c
```

```text
   1 product reviews are currently unavailable
```

The page loads, so the `bridge` policy works. But `bridge` cannot get the reviews from `scout`.

## Step 2: Read the scout access log

The denial is logged by the workload that received the request, `scout`. The proxy writes its log in small batches, so read it a few seconds after loading the page:

```sh
kubectl logs -n starfleet -l app=scout -c istio-proxy --tail=5 | grep rbac_access_denied | tail -1
```

```text
[2026-10-09T07:54:53.132Z] "GET /reviews/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.11.1" "c21e3c5a-b3cb-4cf6-9d60-dcd9c47a8cda" "scout:9080" "-" inbound|9080|| - 10.244.0.10:9080 10.244.0.11:37238 outbound_.9080_._.scout.starfleet.svc.cluster.local default
```

`matched_policy[none]` means the `scout` proxies hold an `ALLOW` policy, and no rule in it matches the request from `bridge`. So the policy arrived, and its rule is wrong.

## Step 3: Compare the rule with the real caller

Read the principal the rule allows, and the service account the `bridge` pod really runs as:

```sh
kubectl get authorizationpolicy scout-allow-bridge -n starfleet \
  -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}{"\n"}'
kubectl get pod -n starfleet -l app=bridge -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'
```

```text
cluster.local/ns/starfleet/sa/bridge
starfleet-bridge
```

The rule names `sa/bridge`. The `bridge` pod runs as `starfleet-bridge`. That is the first fault.

## Step 4: Fix the scout policy

Save this as `authorizationpolicy-scout-allow-bridge.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: scout-allow-bridge
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: scout
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/starfleet-bridge"]
    to:
    - operation:
        methods: ["GET"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-scout-allow-bridge.yaml
```

Then check the result. Wait up to about a minute and load the page a few times:

```sh
for i in 1 2 3 4 5 6; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage \
    | grep -oE 'currently unavailable|glyphicon-star' | sort -u | tr '\n' ' '; echo
done
```

```text



currently unavailable 
```

The reviews are back. But no load shows stars. Empty lines come from `scout` v1, which never shows stars. The `currently unavailable` line came from `scout` v2 or v3: when it asks `navcom` for the rating, it is denied, and the page says `Ratings service is currently unavailable`. That is the second fault.

## Step 5: Find out why navcom denies scout

Ask the `navcom` proxy which policies it holds, and ask `istioctl analyze`:

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
istioctl analyze -n starfleet
```

```text
ns[starfleet]-policy[allow-nothing]
Warning [IST0127] (AuthorizationPolicy starfleet/navcom-allow-scout) No matching workloads for this resource with the following labels: app=navcomm
```

The `navcom` proxy holds only `allow-nothing`, and `analyze` warns about `IST0127`: `navcom-allow-scout` never reached `navcom`. Its selector asks for `app: navcomm`, and no pod carries that label. Editing its rules would change nothing.

## Step 6: Fix the navcom policy

Save this as `authorizationpolicy-navcom-allow-scout.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-allow-scout
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
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

## Step 7: Prove it works

The `navcom` proxy now holds its policy:

```sh
istioctl proxy-config listener deploy/navcom-v1 -n starfleet --port 15006 -o json \
  | grep -o 'ns\[starfleet\]-policy\[[a-z-]*\]' | sort -u
```

```text
ns[starfleet]-policy[allow-nothing]
ns[starfleet]-policy[navcom-allow-scout]
```

Wait up to about a minute, then load the page again. Some loads show stars, and none shows an error:

```sh
for i in 1 2 3 4 5 6; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s http://bridge:9080/productpage \
    | grep -oE 'currently unavailable|glyphicon-star' | sort -u | tr '\n' ' '; echo
done
```

```text
glyphicon-star 



glyphicon-star 
glyphicon-star 
```

And every shortcut from the `shuttle` is still denied, while the front page is open:

```sh
for url in http://bridge:9080/productpage http://cargo:9080/details/0 http://scout:9080/reviews/0 http://navcom:9080/ratings/0; do
  kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null -w "%{http_code} $url\n" "$url"
done
```

```text
200 http://bridge:9080/productpage
403 http://cargo:9080/details/0
403 http://scout:9080/reviews/0
403 http://navcom:9080/ratings/0
```

Now submit:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-02
```

---

## Common Mistakes

- **Opening the namespace.** `rules: [{}]` or deleting `allow-nothing` makes the page work, but it opens every shortcut. The grader checks both.
- **Using `namespaces: ["starfleet"]`.** The page works, but now `shuttle` can call `scout` and `navcom` directly, and gets `200` instead of `403`.
- **Removing the selector from `navcom-allow-scout`.** The policy then covers every workload in the namespace, so `scout` may call all of them. The grader checks that it selects `app: navcom`.
- **Editing the rules of `navcom-allow-scout` first.** Its rules were right. A policy that never reached the proxy is fixed in its `selector`.
- **Testing too fast.** A connection opened before your change can keep the old rules for up to about a minute. If you see a mix of results, wait and load the page again.
