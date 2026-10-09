# Solution Walkthrough

Mission debrief, astronaut. A method rule needs something that reads HTTP. In ambient mode that is a waypoint, and only when traffic goes through it. Once it does, one policy with `targetRefs` handles both the identity and the method.

---

## Step 1: Check the starting point

Ask ztunnel what it knows about the namespace, and look for a waypoint:

```sh
istioctl ztunnel-config workload | grep -E "NAMESPACE|ambient-authz"
kubectl get gateway -n ambient-authz
```

```text
NAMESPACE          POD NAME                                                       ADDRESS     NODE                                   WAYPOINT PROTOCOL
ambient-authz      notification-service-v1-54dd46d4b6-mw6cw                       10.244.0.8  astro-ats-015-lab-060-01-control-plane None     HBONE
ambient-authz      other-client-68fb48c96f-c7htv                                  10.244.0.10 astro-ats-015-lab-060-01-control-plane None     HBONE
ambient-authz      tester-56bcc5dc9c-j95ns                                        10.244.0.9  astro-ats-015-lab-060-01-control-plane None     HBONE
No resources found in ambient-authz namespace.
```

`PROTOCOL: HBONE` means ztunnel carries the pods' traffic and does the mutual TLS for it: they are in the mesh. `WAYPOINT: None` and no `Gateway` mean nothing can read HTTP yet, so a method rule would have nothing to enforce it.

## Step 2: Create the waypoint and send traffic through it

Create the waypoint, and label the namespace so its traffic goes through it, in one command:

```sh
istioctl waypoint apply -n ambient-authz --enroll-namespace
```

```text
✅ waypoint ambient-authz/waypoint applied
✅ namespace ambient-authz labeled with "istio.io/use-waypoint: waypoint"
```

Wait until it is ready, then list it:

```sh
kubectl wait --for=condition=Programmed gateway/waypoint -n ambient-authz --timeout=120s
kubectl get gateway -n ambient-authz
```

```text
gateway.gateway.networking.k8s.io/waypoint condition met
NAME       CLASS            ADDRESS       PROGRAMMED   AGE
waypoint   istio-waypoint   10.96.74.56   True         105s
```

Two things happened, and they are separate. `waypoint apply` created the waypoint: a Gateway API `Gateway` with `gatewayClassName: istio-waypoint`, plus the Deployment Istio builds for it. `--enroll-namespace` added the label `istio.io/use-waypoint=waypoint` to the namespace, which sends the traffic through it. A waypoint without that label runs happily and receives nothing.

You could also label only the Service instead of the namespace:

```sh
kubectl label service notification-service -n ambient-authz istio.io/use-waypoint=waypoint
```

Either label passes the grader.

## Step 3: Write one policy for the waypoint

The rule mixes an identity (`principals`) and a method (`methods`). The waypoint can check both, because it reads the request and it sees the caller's certificate. Attach it with `targetRefs`, so it lands on the waypoint in front of the Service.

Save this as `authorizationpolicy-notification-l7.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-l7
  namespace: ambient-authz
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: notification-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/ambient-authz/sa/tester-sa
    to:
    - operation:
        methods: ["POST"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-notification-l7.yaml
```

```text
authorizationpolicy.security.istio.io/notification-l7 created
```

Wait about a minute: a new policy takes that long to reach live traffic, because open connections keep the old rule. Then check the result. Send the three calls from the task:

```sh
kubectl exec -n ambient-authz deploy/tester -- curl -s -o /dev/null -w "tester POST: %{http_code}\n" -X POST http://notification-service/notify
kubectl exec -n ambient-authz deploy/tester -- curl -s -o /dev/null -w "tester GET:  %{http_code}\n" -X GET http://notification-service/notify
kubectl exec -n ambient-authz deploy/other-client -- curl -s -o /dev/null -w "other-client POST: %{http_code}\n" -X POST http://notification-service/notify
```

```text
tester POST: 200
tester GET:  403
other-client POST: 403
```

All three come from one policy. `principals` gives the identity half, `methods` the method half, and the waypoint enforces both. `other-client` gets `403`, an HTTP answer from the waypoint, not a closed connection.

`group: ""` is the Kubernetes core API group, where `Service` lives.

## Step 4: Why not add a pod-level identity rule too

It is tempting to keep an old-style L4 rule as well: a `selector` on `app: notification-service` that allows only `tester-sa`. Do not. With the waypoint in the path, every connection reaches the pod **from the waypoint**, with the waypoint's identity, `cluster.local/ns/ambient-authz/sa/waypoint`. A rule that allows only `tester-sa` refuses the waypoint, so the service stops answering everyone, `tester` included.

Two `ALLOW` policies on the same target also add up. A second policy without `methods` would allow the `GET` that the first one refuses. One policy at the waypoint is the clean answer.

## Step 5: Ask each component what it holds

List the policies ztunnel enforces, then read the waypoint's flight log:

```sh
istioctl ztunnel-config policy
kubectl logs -n ambient-authz deploy/waypoint --tail=3
```

```text
NAMESPACE POLICY NAME ACTION SCOPE
[2026-10-09T12:01:35.751Z] "POST /notify HTTP/1.1" 200 - via_upstream - "-" 0 49 2 1 "-" "curl/8.22.0" "2663a66e-e537-41c5-b452-d12bc7acf28b" "notification-service" "envoy://connect_originate/10.244.0.8:8084" inbound-vip|80|http|notification-service.ambient-authz.svc.cluster.local envoy://internal_client_address/ 10.96.231.28:80 10.244.0.9:36658 - default
[2026-10-09T12:01:35.827Z] "GET /notify HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.22.0" "11e87b94-c9ae-42d4-852e-5c4d4b107103" "notification-service" "-" inbound-vip|80|http|notification-service.ambient-authz.svc.cluster.local - 10.96.231.28:80 10.244.0.9:36658 - default
[2026-10-09T12:01:35.899Z] "POST /notify HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.22.0" "bc02e383-75c3-4465-afb0-fbbe29590e40" "notification-service" "-" inbound-vip|80|http|notification-service.ambient-authz.svc.cluster.local - 10.96.231.28:80 10.244.0.10:42840 - default
```

ztunnel prints only its header line: it holds no policy at all, because the only policy uses `targetRefs` and so lives on the waypoint. The waypoint log has one line per call. The two refused calls show `403` and `rbac_access_denied_matched_policy[none]`: no `ALLOW` rule matched them. The waypoint writes its log in batches, so if the lines are missing, wait a few seconds and run the command again.

## Step 6: Submit

```sh
astrona submit -c sections/section-060/module-01/labs/lab-01
```

## If it does not pass

- **`tester GET` still returns `200`.** There is no waypoint, or it exists but nothing carries the `istio.io/use-waypoint` label, or the policy uses a `selector` instead of `targetRefs`.
- **Every caller gets `000` or `503`.** A pod-level `selector` policy refuses the waypoint's identity. Delete it and keep only the `targetRefs` policy.
- **`tester POST` gets `403`.** The principal string is wrong. It must be `cluster.local/ns/ambient-authz/sa/tester-sa`, without `spiffe://`.
- **`other-client` gets `200`.** The rule has no `from` part, so it allows every identity.
