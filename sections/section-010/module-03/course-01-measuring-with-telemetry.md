# Part 1 — Measuring before you change anything

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Exceptions, and moving callers into the mesh](./course-02-exceptions-and-meshing.md).

The first step of a migration changes no configuration at all. It answers one question with evidence: **is anything still sending plaintext to this namespace?** Everything after it is wasted if the answer was guessed, so this part is about where the answer lives, how to get it, and — just as important — what it cannot tell you.

## Where the number comes from

Every Istio sidecar counts the requests it handles. The counter is `istio_requests_total`, and it carries a label that answers the migration's question directly:

```text
connection_security_policy="mutual_tls"   the request arrived over mTLS
connection_security_policy="none"         the request arrived in plaintext
```

Two mechanical facts decide how you read it.

**It is a server-side counter.** The label describes how a request *arrived*, which is only knowable by the proxy that terminated the connection. So you query the workload being called, not the caller. Querying the client tells you what it sent, which is a different question and, in a migration, the less useful one — you are trying to find callers you have forgotten about, and by definition you do not know where to look for them.

**It lives in Envoy, not in a database.** The path from request to number is short and entirely inside the pod:

```text
   request arrives at the sidecar
         │
         ▼
   Envoy terminates the connection,  records how: mutual_tls | none
         │
         ▼
   Envoy's stats sink  ──────▶  admin endpoint  /stats/prometheus
         │                              ▲
         │                              │ pilot-agent request GET stats/prometheus
         │                              │   (from inside the container)
         ▼                              │
   scraped by Prometheus, if one exists ┘
```

`pilot-agent` is the sidecar's own agent process — the same one that fetched the certificate in [Module 1](../module-01/course-01-how-identity-is-issued.md). `pilot-agent request GET stats/prometheus` asks Envoy's local admin interface for its metrics from inside the container. No Prometheus installation is required, which is exactly why this works in a playground and in a cluster where monitoring is someone else's team.

Counters only count what has happened, so send some traffic first, from both a meshed and an unmeshed client.

> [!TIP]
> **Try it — find out whether any plaintext is still arriving**
>
> ```sh
> kubectl -n migrate-demo exec deploy/tester -- sh -c \
>   'for i in $(seq 1 10); do curl -s -o /dev/null -X POST http://notification-service/notify; done'
> kubectl -n outside exec deploy/outside-client -- sh -c \
>   'for i in $(seq 1 10); do curl -s -o /dev/null -X POST http://notification-service.migrate-demo/notify; done'
>
> kubectl -n migrate-demo exec deploy/notification-service-v1 -c istio-proxy -- \
>   pilot-agent request GET stats/prometheus | grep istio_requests_total \
>   | grep -o 'connection_security_policy="[^"]*"' | sort | uniq -c
> ```
>
> Expect something like:
>
> ```text
>   10 connection_security_policy="mutual_tls"
>   10 connection_security_policy="none"
> ```
>
> The counts are examples and depend on how much traffic you generated. The line that matters is the second one: `none` is present, so at least one caller would break the instant this namespace went `STRICT`. That is the whole check, and it is evidence rather than belief.
>
> Note `-c istio-proxy` — this runs in the sidecar container, not the application container, because the sidecar is what holds the counter.

## Finding *which* caller

The label says plaintext happened; it does not say who. `istio_requests_total` carries other labels that do, and the same one-liner extended by one field usually names the culprit:

```sh
kubectl -n migrate-demo exec deploy/notification-service-v1 -c istio-proxy -- \
  pilot-agent request GET stats/prometheus | grep istio_requests_total \
  | grep 'connection_security_policy="none"' \
  | grep -o 'source_workload="[^"]*"'
```

An unmeshed caller has no sidecar to report itself, so `source_workload` is often `unknown` — which is itself informative: `unknown` plus `none` means the caller is outside the mesh entirely, rather than a meshed workload that was configured to send plaintext. A real name plus `none` points at a `DestinationRule`, which [Part 3](./course-03-enforcing-and-rolling-back.md) returns to.

In a cluster with real monitoring, the same query against Prometheus is more comfortable and scales past one workload:

```text
sum by (source_workload, source_workload_namespace) (
  rate(istio_requests_total{connection_security_policy="none",
                            destination_service_namespace="migrate-demo"}[1h])
)
```

## What this measurement cannot prove

A counter is a record of the past, and the migration decision is about the future. Three limits follow, and all three have bitten real migrations:

- **Absence of evidence is not evidence of absence.** A scraper that runs hourly, a nightly batch job, a quarterly report — none of them appear in a counter you read one minute after generating test traffic. The measurement window must be longer than the interval of your slowest periodic caller. When you do not know that interval, a week is the honest default.
- **Counters are cumulative, and never reset.** The `none` samples you saw above stay in the total forever, so "the count stopped going up" is the thing to check after migrating, not "the count is zero". Either record the number and compare, or use `rate()` in Prometheus, which answers the question directly.
- **A pod restart resets them.** The counter lives in an Envoy process. If `notification-service-v1` is redeployed mid-measurement, the history goes with it. That is another argument for Prometheus over a one-off `exec` when the window is measured in days.

As an analogy: this is a footfall counter on a door, not a guest list. It tells you people came through and how, and it cannot tell you who did not come today but will tomorrow. Where the analogy breaks down: unlike footfall, you can also reason from configuration — every caller you *can* enumerate is one you do not have to wait to observe.

> *`connection_security_policy` on the receiving proxy is the only direct evidence that nothing is still sending plaintext — and a counter proves what happened, never what is about to.*

## Reference

- [Istio standard metrics](https://istio.io/latest/docs/reference/config/metrics/) — the full label set on `istio_requests_total`, including `source_workload` and `connection_security_policy`.
- [Mutual TLS migration task](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/) — Istio's own procedure, with the telemetry step first.
- [`istioctl proxy-config`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config) — the configuration-side complement to these traffic-side counters.
