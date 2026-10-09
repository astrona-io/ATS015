# Part 2 — Exceptions, and moving callers into the mesh

> Prerequisite: [Part 1 — Measuring before you change anything](./course-01-measuring-with-telemetry.md). Next: [Part 3 — Enforcing, verifying and rolling back](./course-03-enforcing-and-rolling-back.md).

Part 1 told you plaintext is still arriving. This part is the work that makes that stop: writing down the state you are in, carving out the callers that genuinely cannot be fixed, and moving the rest into the mesh. It is the longest step in a real migration and the only one that disrupts anything.

## Declare the state you are in

The second step of the procedure changes no behaviour at all, and is worth doing anyway: write out the `PERMISSIVE` policy explicitly.

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: PERMISSIVE
```

Two reasons, and the second is the one that matters at three in the morning.

**It makes the namespace reviewable.** "No policy" and "deliberately permissive" produce identical behaviour and mean completely different things in a change request. After [Module 2](../module-02/course-02-scopes-and-precedence.md) you know the effective mode is resolved from whichever policy is narrowest — and that an absent policy resolves to `PERMISSIVE` by default. Writing it down converts an inherited default into a decision someone made.

**It is your rollback.** The flip in [Part 3](./course-03-enforcing-and-rolling-back.md) is a one-line change to this same object. If it goes wrong, restoring service is `kubectl apply` of a file you already have, rather than reconstructing YAML under pressure while callers fail.

## Exempt what genuinely cannot do mTLS

Some traffic will never be mTLS: a metrics scraper outside the mesh, a legacy health checker, a load balancer probe with no certificate to present. For those, `portLevelMtls` carves out a single port while the rest of the workload goes strict.

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: notification-metrics-exception
  namespace: migrate-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  mtls:
    mode: STRICT
  portLevelMtls:
    9090:
      mode: PERMISSIVE
```

The object contradicts itself on purpose — workload-level `STRICT`, port-level `PERMISSIVE` — and resolves exactly as [Module 2](../module-02/course-02-scopes-and-precedence.md) described: narrowest wins, and a port is narrower than a workload.

The mechanism decides what "port" means here, and it is the detail people get wrong. The policy is compiled onto the workload's **inbound listener**, which Envoy builds from the ports the pod actually listens on:

```text
   pod spec: containerPort 8084, containerPort 9090
        │
        ▼
   inbound listeners:  0.0.0.0:8084   0.0.0.0:9090
                            │              │
   portLevelMtls: 9090 ─────────────────── ▶ attaches here
   portLevelMtls: 80   ─── nothing to attach to ──▶ silently ignored
```

So the number is the **container port**, not the `Service` port that fronts it. And an entry naming a port the workload does not serve is accepted by the API, stored in the object, and does nothing — no error, no event, no warning. Since the rest of the workload is now strict, the scraper you were protecting breaks the next time it runs, hours later, with nothing connecting cause to effect.

This one is written to be read rather than run: `notification-service` in the playground listens on `8084` and nothing else, so there is no `9090` listener for the exception to attach to. Applying it demonstrates exactly the silent failure above, which is worth doing once deliberately. To see an exception *work*, write it for `8084` and watch the whole workload become permissive again.

## Mesh the remaining callers

This is the step with the actual work in it, and the one that needs a maintenance window in a real cluster.

Injection is done by a **mutating admission webhook**. istiod registers it with the API server; the API server calls it while a pod is being created; the webhook returns a modified pod spec with the `istio-proxy` container (and an init container) added. Read that sequence carefully and the behaviour that surprises everyone becomes obvious:

```text
   kubectl apply / a controller creates a Pod
        │
        ▼
   API server: is this namespace labelled istio-injection=enabled ?
        │                                  (or pod-level annotation)
       yes
        │
        ▼
   sidecar-injector webhook  →  pod spec + istio-proxy container
        │
        ▼
   Pod object is written to etcd, then scheduled
```

The webhook runs **at pod creation time**. It has no mechanism to reach a pod that already exists — the spec was written before the label existed, and a running pod's container list is immutable. So labelling a namespace changes precisely nothing about what is running in it; the next pod created there gets a sidecar, and that is all.

Which makes a restart the actual migration step, and `kubectl rollout restart` the tool: it replaces pods under the Deployment's normal rolling strategy, so each new pod goes through the webhook on the way in.

> [!TIP]
> **Try it — move `outside-client` into the mesh**
>
> ```sh
> kubectl label namespace outside istio-injection=enabled
> kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> kubectl -n outside rollout restart deployment outside-client
> kubectl -n outside rollout status deployment outside-client
> kubectl -n outside get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> POD                              CONTAINERS
> outside-client-8f9d7c6b5-n4xqr   outside-client
> deployment.apps/outside-client restarted
> deployment "outside-client" successfully rolled out
> POD                              CONTAINERS
> outside-client-6c4b8d9f7-vt2km   outside-client,istio-proxy
> ```
>
> The first listing is after labelling and shows one container — the label alone did nothing, exactly as the webhook diagram predicts. The second, after the restart, shows `istio-proxy` alongside the application. In a production namespace this restart is the disruptive part of the migration, and it is why migrations are done a workload at a time.

Two practical consequences of doing it this way:

- **Pods not owned by a controller do not come back.** A bare `Pod` has nothing to recreate it, so `rollout restart` does not apply and deleting it just removes it. Those need handling individually, and finding them before the window rather than during it is worth the five minutes.
- **The new pod is a new identity holder, not a new identity.** It gets its own certificate through the flow in [Module 1](../module-01/course-01-how-identity-is-issued.md), but the SPIFFE URI is unchanged — same namespace, same service account. Policies written against it keep working across the restart.

## Re-measure before going further

With the last plaintext caller meshed, repeat [Part 1](./course-01-measuring-with-telemetry.md)'s check. The counters still hold the `none` samples from before the migration, because counters never reset — so the question to ask is not "is it zero" but "did it stop going up".

Either record the count, generate fresh traffic, and compare; or use `rate()` against Prometheus, which answers it directly. Only when nothing *new* arrives as `none` is the namespace ready for the flip.

> *Labelling a namespace tells the webhook what to do next time; only recreating the pod makes it happen — which is why the restart, not the label, is the migration.*

## Common pitfalls

> [!WARNING]
> **Meshing a caller and expecting it to be immediate.** Injection happens at pod creation, so nothing changes until the pods are recreated.
>
> **Restarting a pod that no controller owns.** A bare pod deleted is a bare pod gone. Check for a Deployment or StatefulSet before deleting anything.
>
> **Expecting a new pod to have a new identity.** The identity comes from the service account, so a recreated pod holds the same one.
>
> **Leaving an exemption in place after the exception ends.** A narrow `PERMISSIVE` written for one legacy caller outlives the caller unless someone removes it.

## Reference

- [Sidecar injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/) — the webhook, the namespace label, the pod-level annotation, and why existing pods are unaffected.
- [PeerAuthentication reference](https://istio.io/latest/docs/reference/config/security/peer_authentication/) — the `portLevelMtls` map and its relationship to the workload-level mode.
- [Kubernetes admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) — what a mutating webhook can and cannot change, and when it runs.
