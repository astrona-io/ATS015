# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and every mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about authorization when the ships fly without a communications officer: ztunnel enforces rules on the connection (L4), and a waypoint enforces rules on the request (L7).

**From [The Ambient Dataplane](./course-01-the-ambient-dataplane.md):**

- ztunnel runs once per node. It does the mutual TLS for every enrolled pod and enforces L4 rules. It never reads HTTP.
- ztunnel sends traffic through HBONE: HTTP/2 `CONNECT` inside mutual TLS, on port `15008`. The caller's certificate travels on the tunnel, so identity is always known.
- istio-cni redirects pod traffic to ztunnel. The label `istio.io/dataplane-mode=ambient` enrols the pods already running, with no restart and no extra container.
- `istioctl ztunnel-config workload` shows `PROTOCOL: HBONE` for an enrolled pod, and its `WAYPOINT` column.

**From [What ztunnel Can Enforce](./course-02-what-ztunnel-can-enforce.md):**

- ztunnel can enforce `principals`, `namespaces`, `ipBlocks` and `ports`. It cannot enforce `methods`, `paths`, `hosts`, `requestPrincipals` or `when` conditions on the request.
- An identity rule with a `selector` works with no waypoint.
- An L4 refusal closes the connection: `curl` shows `000`. A waypoint refusal is an HTTP `403`.
- ztunnel's log names the caller, the target and the reason for each refused connection.

**From [A Rule With Nowhere To Run](./course-03-a-rule-with-nowhere-to-run.md):**

- An L7 rule attached with `targetRefs` and no waypoint is accepted, listed and ignored. Its status condition `WaypointAccepted` is `False`, and `istioctl analyze` warns with `IST0171`.
- An L7 rule attached with a `selector` is sent to ztunnel, which fails safe: it drops the rule (`"rules": []` in `istioctl ztunnel-config policy -o json`), so the `ALLOW` matches nothing and every caller is refused.
- `selector` points at pods (ztunnel). `targetRefs` of kind `Service` points at that Service's waypoint; of kind `Gateway`, at the waypoint itself.

**From [Deploy A Waypoint](./course-04-deploy-a-waypoint.md):**

- `istioctl waypoint apply` creates the waypoint. The label `istio.io/use-waypoint` on a namespace or Service sends signals through it. Both steps are needed.
- With the waypoint in the path, the same `targetRefs` policy starts to work, and refusals become `403`.
- Behind a waypoint, the destination's ztunnel sees the waypoint's identity. A pod-level rule that allows only the original caller then refuses everyone.

**From [Ask Who Holds The Rule](./course-05-ask-who-holds-the-rule.md):**

- `istioctl ztunnel-config policy` lists the rules ztunnel enforces. Waypoint rules show in the waypoint's listeners and access log.
- When a policy does nothing, ask: does it exist, does a component hold it, does it match?
- Identity, policy structure and evaluation order stay as in sidecar mode. JWT rules always need a waypoint.

## Your missions

You proved each skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Allow Only Known Ships At L4](./labs/lab-02/README.md) | What ztunnel Can Enforce | lock two ships to the right callers with identity rules that ztunnel enforces alone |
| [Enforce L4 And L7 Policy In Ambient Mode](./labs/lab-01/README.md) | Deploy A Waypoint | add a waypoint, route a service through it, and enforce identity plus method with `targetRefs` |

If you skipped one, go back to it now. Each mission is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You label a namespace <code>istio.io/dataplane-mode=ambient</code>. Do the running pods need a restart?</summary>

No. istio-cni redirects the traffic of running pods to ztunnel straight away. Nothing in the pod changes.
</details>

<details>
<summary>2. An ambient namespace has no waypoint. Can an <code>ALLOW</code> on <code>principals</code> work?</summary>

Yes. ztunnel reads the caller's identity from the certificate on the HBONE tunnel, so it enforces `principals` and `namespaces` on its own.
</details>

<details>
<summary>3. A caller gets <code>000</code> from <code>curl</code>. Another gets <code>403</code>. Which component refused each one?</summary>

`000` is a closed connection: ztunnel refused it at L4. `403` is an HTTP answer: a waypoint refused it at L7.
</details>

<details>
<summary>4. You apply an <code>ALLOW</code> with <code>methods: ["GET"]</code> and <code>targetRefs</code> on a Service. No waypoint exists. What happens to a <code>POST</code>?</summary>

It passes. The policy is meant for the Service's waypoint, and there is none, so nothing enforces it.
</details>

<details>
<summary>5. The same rule, but attached with a <code>selector</code>. What happens now?</summary>

ztunnel must enforce it and cannot read `methods`, so it fails safe. The rule never matches, and the `ALLOW` refuses every caller, `GET` included.
</details>

<details>
<summary>6. The waypoint shows <code>PROGRAMMED: True</code>, but the method rule still does nothing. What is missing?</summary>

The `istio.io/use-waypoint` label on the namespace or the Service. Without it, no signal goes through the waypoint.
</details>

<details>
<summary>7. After you add a waypoint for the whole namespace, the pod-level rule on <code>cargo</code> that allows only <code>starfleet-bridge</code> blocks everyone. Why?</summary>

Signals now reach the pod from the waypoint, so the pod's ztunnel sees the waypoint's identity, not `starfleet-bridge`. Move the identity rule to the waypoint with `targetRefs`, or also allow the waypoint's identity.
</details>

<details>
<summary>8. Which command shows the policies that ztunnel actually enforces?</summary>

`istioctl ztunnel-config policy`. Compare it with `kubectl get authorizationpolicy`: a policy that is in the second list and held by no component does nothing.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any mission that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-060-01
```

If `astrona list` also showed a mission, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-060-01-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *ztunnel enforces who may connect, a waypoint enforces what they may ask, and a rule that neither of them holds is only words in a YAML file.*
