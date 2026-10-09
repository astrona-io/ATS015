# Read The mTLS Mode A Pod Uses

A `PeerAuthentication` sets whether a workload accepts plain text, mTLS or both on inbound connections. Up to now you could judge each policy by a status code, and that works when the result is what you expected. When it is not, a failed request only tells you that *something* refused it. It does not tell you which policy decided, or whether your policy reached the pod at all.

This chapter shows you how to ask the pod's sidecar proxy (Envoy) directly which `PeerAuthentication` it follows. You start with a short summary from `istioctl x describe pod`, then look at the evidence in the sidecar's inbound listener, and end with the mistakes these two tools catch.

## Two questions, two tools

When a policy seems to do nothing, you need to answer two separate questions, and asking them in this order saves most of the searching.

The first question is which policies exist, anywhere. `kubectl get peerauthentication -A` lists every policy in every namespace. Together with the scope rules (the namespace the policy lives in, and whether it has a `selector`), that list is most of what you need to work out the mode of any pod. A forgotten policy, or one in the wrong namespace, shows up here and nowhere else.

The second question is what the pod actually got. For that, `istioctl` asks the pod's sidecar proxy what configuration it holds. Two commands help here: `istioctl x describe pod` gives a short summary in plain words, and `istioctl proxy-config listener` shows the listener itself.

## Ask the pod

`istioctl x describe pod` reads a pod's Istio configuration and prints a summary. The `x` stands for "experimental": the command works fine, but its output format may still change between versions. To see it work, you need one policy in place.

<!-- astrona:playground:renew -->

Apply the namespace-wide `STRICT` policy for `starfleet` that you saved as `peerauthentication-starfleet-strict.yaml`, then list every policy:

```sh
kubectl apply -f peerauthentication-starfleet-strict.yaml
kubectl get peerauthentication -A
```

```text
peerauthentication.security.istio.io/default created
NAMESPACE   NAME      MODE     AGE
starfleet   default   STRICT   0s
```

There is one policy, in one namespace, with no `selector`. Now put the name of one `probe` pod in a variable, and describe that pod:

```sh
PROBE_POD=$(kubectl get pod -n starfleet -l app=probe,version=v1 -o jsonpath='{.items[0].metadata.name}')
istioctl x describe pod $PROBE_POD -n starfleet
```

```text
Pod: probe-v1-7888d6c6d5-wlv42
   Pod Revision: default
   Pod Ports: 8080 (probe)
--------------------
Service: probe
   Port: http 8000/HTTP targets pod port 8080
--------------------
Effective PeerAuthentication:
   Workload mTLS mode: STRICT
Applied PeerAuthentication:
   default.starfleet
Skipping Gateway information (no ingress gateway pods)
```

Your pod name ends in different letters. Two entries matter. **Workload mTLS mode** is the mode that won. **Applied PeerAuthentication** lists every policy that covers this pod, as `<name>.<namespace>`. Here only one policy exists, so the list has one name. The output also shows the two port numbers side by side: Service port `8000` targets pod port `8080`.

When several policies cover a pod, all of them appear in that list, separated by commas. A pod covered by a mesh, a namespace and a workload policy shows three names. The list does not mark a winner, so apply the scope rule yourself: the narrowest policy in the list decides, and **Workload mTLS mode** shows its result.

## Ask the listener

`describe` gives you the conclusion, and the listener gives you the evidence. The sidecar's inbound listener, the part of Envoy that accepts incoming connections, holds **filter chains**: sets of steps for one kind of connection. Under `PERMISSIVE` it has two, one for mTLS and one for plain text. Under `STRICT` it has only the mTLS one.

Inside the sidecar, all inbound connections arrive on one listener, on port `15006`. It holds filter chains for each port the pod listens on. List the chains for the `probe`'s container port, `8080`:

```sh
istioctl proxy-config listener deploy/probe-v1 -n starfleet --port 15006 | grep 8080
```

```text
0.0.0.0   15006 Trans: tls; Addr: *:8080                                Cluster: inbound|8080||
```

There is one row for port `8080`, and it expects TLS (`Trans: tls`). There is no chain for plain text, which is why the `drifter`'s connection is closed. To see the difference, remove the policy and list the chains again:

```sh
kubectl delete -f peerauthentication-starfleet-strict.yaml
istioctl proxy-config listener deploy/probe-v1 -n starfleet --port 15006 | grep 8080
```

```text
peerauthentication.security.istio.io "default" deleted from starfleet namespace
0.0.0.0   15006 Trans: tls; App: istio,istio-peer-exchange,istio-http/1.0,istio-http/1.1,istio-h2; Addr: *:8080 Cluster: inbound|8080||
0.0.0.0   15006 Trans: raw_buffer; Addr: *:8080                                                                 Cluster: inbound|8080||
```

A plain-text chain (`Trans: raw_buffer`) is back next to the TLS chain. That is `PERMISSIVE`, seen from inside the sidecar. No pod restarted: `istiod` pushed the change to the running sidecar.

## When the pod and the YAML disagree

If the traffic and your YAML disagree, the rule itself is almost never the problem. The problem is that the policy did not land where you meant it to. Three mistakes all look normal in `kubectl get`, and all show up in `describe`:

- **A policy in the wrong namespace.** `describe` names a different policy, or none.
- **A `selector` that matches no pod.** The workload policy never appears under "Applied PeerAuthentication".
- **A port-level setting on a port the pod does not listen on.** The mode for the real port does not change.

The habit to build from this works for every security object in this course: prove a policy with real traffic first, then confirm with `istioctl` that the sidecar received it.

> [!TIP]
> In the exam, run `istioctl x describe pod` on one pod after every `PeerAuthentication` you apply. It takes five seconds, and it shows the mode that won and every policy that covers the pod, before you spend time sending test requests.

You can now read a pod's real mode in two ways. `istioctl x describe pod` shows the mode that won and every policy that covers the pod, and the listener's filter chains show what that mode did inside the sidecar. Both tools work on whole workloads, but a mode can also be set for a single port, which raises the question of how to open just one port and nothing else.

## Common pitfalls

> [!WARNING]
> - **Trusting `kubectl get` alone.** It shows that an object exists, not that it covers the pod you meant. Check the pod with `istioctl x describe pod`.
> - **Looking for the listener on the app port.** The sidecar receives every inbound connection on port `15006`. The app's port (`8080`) shows up inside that listener's filter chains.
> - **Using the Service port when reading the listener.** The listener knows the container port (`8080`), not the Service port (`8000`).
> - **Checking too fast.** `kubectl apply` returns before the new configuration reaches the sidecar. If the output still looks old, wait a second and run it again.
