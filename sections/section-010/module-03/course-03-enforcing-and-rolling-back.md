# Part 3 — Enforcing, verifying and rolling back

> Prerequisite: [Part 2 — Exceptions, and moving callers into the mesh](./course-02-exceptions-and-meshing.md). Next: [the module landing page](./course.md), then [Section 020 — Authorization Policy Fundamentals](../../section-020/README.md).

Everything is measured, exempted and meshed. This part is the ten-second change the whole procedure exists to make safe — plus the one thing that can still break it, and the rollback that makes the risk acceptable.

## The flip

Apply the `STRICT` namespace policy, keeping any `portLevelMtls` exception alongside it.

> [!TIP]
> **Try it — flip to `STRICT` and confirm nothing broke**
>
> ```sh
> kubectl apply -f - <<'YAML'
> apiVersion: security.istio.io/v1
> kind: PeerAuthentication
> metadata:
>   name: default
>   namespace: migrate-demo
> spec:
>   mtls:
>     mode: STRICT
> YAML
>
> kubectl -n migrate-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w 'in-mesh: %{http_code}\n' -X POST http://notification-service/notify
> kubectl -n outside exec deploy/outside-client -- \
>   curl -s -o /dev/null -w 'migrated: %{http_code}\n' --max-time 5 -X POST http://notification-service.migrate-demo/notify
> ```
>
> Expect something like:
>
> ```text
> in-mesh: 200
> migrated: 200
> ```
>
> Both succeed because both are now meshed — which is the entire point of doing the migration before the flip. Roll back at any time by re-applying the `PERMISSIVE` version of this same object. If you had skipped [Part 2](./course-02-exceptions-and-meshing.md)'s meshing step, the second line would read `000`.

Note what this change is *not*: it is not a restart, not a redeploy, and not a window. The policy reaches running proxies as a configuration push within seconds, the same way certificates do. Both the break and the fix are that fast, which is what makes the rollback below meaningful rather than theoretical.

## Verify configuration, not just traffic

Two successful requests prove those two callers work. They do not prove the policy is doing what you think, and in particular they say nothing about the exception — which is the part that fails silently.

Use the same tool as [Module 2, Part 3](../module-02/course-03-proving-what-is-in-effect.md):

```sh
istioctl proxy-config listener deploy/notification-service-v1 -n migrate-demo \
  --port 8084 -o json | grep -i requireClientCertificate
```

`true` on the application port is the flip, confirmed as configuration. Run the same command against whichever port you exempted and it should report `false`. That check is worth doing every time, because an exception that silently failed to apply — a `Service` port instead of a container port, a port nothing listens on — is indistinguishable from one that worked, right up until the scraper next runs.

## The client side can still break you

`PeerAuthentication` governs what a server accepts. What a client *sends* is decided by the client proxy, and by default meshed clients use mTLS to meshed servers without being told. A `DestinationRule` can override that:

```yaml
spec:
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL   # force mesh mTLS — the default, written down
      # mode: DISABLE      # send plaintext
```

`DISABLE` is the trap, and it produces a failure shaped unlike any other in this module:

```text
   caller           sends          server accepts        result
   ──────           ─────          ──────────────        ──────
   meshed           mTLS           STRICT                200
   unmeshed         plaintext      STRICT                000   ← fixed by meshing
   meshed, with a   plaintext      STRICT                000   ← meshing does not help
   DestinationRule                                              and both pods look fine
   tls.mode: DISABLE
```

Both sides are meshed. Both pods are healthy. Both have valid certificates. Nothing in either pod spec explains it, and the telemetry from [Part 1](./course-01-measuring-with-telemetry.md) reported this caller as `none` with a real `source_workload` name rather than `unknown` — which, in hindsight, was the clue.

When a migration breaks exactly one caller while its neighbours succeed, a stale `DestinationRule` on that caller's route is the first thing to look for:

```sh
kubectl get destinationrule -A -o yaml | grep -B15 'mode: DISABLE'
```

Most of what goes wrong here is sequencing rather than syntax, and each mistake has a specific fix.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **Flipping to `STRICT` without reading telemetry** — the failures land in the callers' logs as connection resets, often in a team that does not know the mesh changed.
>
> **Forgetting the callers that are not applications** — Prometheus, health checkers, backup jobs, and anything in another namespace that was never meshed.
>
> **A measurement window shorter than your slowest periodic caller** — an hourly scraper is invisible in a one-minute sample.
>
> **Reading a cumulative counter as if it reset** — after migrating, check that `none` stopped increasing, not that it is zero.
>
> **Using the `Service` port in `portLevelMtls`** — it takes the workload's container port, and a wrong port is ignored silently.
>
> **Labelling a namespace for injection and expecting existing pods to change** — the webhook runs at pod creation. Existing pods need a restart.
>
> **Leaving a client-side `DestinationRule` with `tls.mode: DISABLE`** — the server demands mTLS, the client refuses to send it, and every request fails even though both sides are meshed.
>
> **Not keeping the `PERMISSIVE` manifest to hand** — rollback is one `kubectl apply`, but only if the file exists.

## Rollback

The rollback is re-applying the `PERMISSIVE` object from [Part 2](./course-02-exceptions-and-meshing.md). It restores service in seconds, for the same reason the flip broke it in seconds — both are configuration pushes to running proxies.

Two things make that a real plan rather than a hopeful one:

- **Have the file, not the intention.** Keep the `PERMISSIVE` manifest in the same directory, applied and committed, before you flip.
- **Decide the trigger in advance.** "Connection resets appear in any caller's logs" is a rollback trigger. "It feels wrong" is not. Under pressure, having written the condition down beforehand is what stops the rollback being debated for twenty minutes.

Rolling back is not a failure of the procedure; it is the procedure working. The expensive mistake is leaving a broken namespace strict while investigating.

## The procedure, compressed

1. **Measure.** `connection_security_policy` on the server. Give it a window longer than your slowest periodic caller.
2. **Declare.** Write the current `PERMISSIVE` mode explicitly — it is also your rollback file.
3. **Exempt.** `portLevelMtls` for anything that genuinely cannot do mTLS, using container ports, verified on the listener.
4. **Mesh.** Label, then restart. The restart is the disruptive step.
5. **Re-measure.** No *new* `none` samples.
6. **Enforce.** Apply `STRICT`, test real traffic, confirm on the listener, and keep the rollback manifest to hand.

Steps 1 and 5 are the ones people under time pressure skip, and they are the only two that distinguish this from guessing.

> *The flip is a configuration push, so it breaks in seconds and recovers in seconds — which makes a written-down rollback trigger worth more than confidence.*

## Reference

- [Mutual TLS migration task](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/) — Istio's own end-to-end procedure for this migration.
- [DestinationRule TLS settings](https://istio.io/latest/docs/reference/config/networking/destination-rule/#ClientTLSSettings) — `ISTIO_MUTUAL`, `DISABLE`, and the client-side half of the handshake.
- [PeerAuthentication reference](https://istio.io/latest/docs/reference/config/security/peer_authentication/) — the object being flipped, including `portLevelMtls`.
