# Lifetime And Rotation

A workload certificate is deliberately short-lived. If a key leaks, the certificate is worthless after its expiry, and Istio has no revocation list to maintain. This chapter covers the default lifetime, the limit that `istiod` enforces, the point where a sidecar renews, and the one setting you can change per workload.

<!-- astrona:playground:renew -->

## The numbers

These values come from the `pilot-discovery` and `pilot-agent` references of Istio 1.30:

| Setting | Where | Default |
| --- | --- | --- |
| `DEFAULT_WORKLOAD_CERT_TTL` | `istiod` environment | `24h`: the lifetime it gives a certificate when the request does not ask for one |
| `MAX_WORKLOAD_CERT_TTL` | `istiod` environment | `2160h`: the longest lifetime it grants, whatever a workload asks for |
| `SECRET_TTL` | `pilot-agent` (sidecar) environment | `24h`: the lifetime a sidecar requests in its CSR |
| `SECRET_GRACE_PERIOD_RATIO` | `pilot-agent` environment | `0.5`: the fraction of the lifetime after which a sidecar renews |

A sidecar asks for `SECRET_TTL`. `istiod` grants it if it is not above `MAX_WORKLOAD_CERT_TTL`. With the defaults the certificate lives 24 hours.

Check it with the playground. Run `chain` and print the dates:

```sh
chain
openssl x509 -in proxy-cert-1.pem -noout -startdate -enddate
```

`notAfter` is about 24 hours after `notBefore`.

## When a sidecar renews

The agent does not wait for expiry. It renews when the grace period ratio of the lifetime has passed. With a 24-hour lifetime and a ratio of `0.5`, the agent requests a new certificate after about 12 hours. It sends a new CSR, receives a certificate, and pushes it to Envoy through SDS. Envoy switches to the new certificate without a restart and without dropping open connections.

Because the renewal happens at half life, a short lifetime means frequent signing requests to `istiod`. A two-hour lifetime means a renewal about every hour for each workload. In a large mesh that load matters, so shorten the lifetime only where the requirement justifies it.

## Set the lifetime of one workload

The sidecar reads `SECRET_TTL` from its environment. You set it per workload through the `proxy.istio.io/config` annotation on the pod template, which carries a `ProxyConfig` document. Its `proxyMetadata` field sets environment variables on the proxy. This patch gives the `probe-v1` Deployment a two-hour lifetime:

```sh
kubectl patch deploy/probe-v1 -n starfleet --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"proxy.istio.io/config":"proxyMetadata:\n  SECRET_TTL: 2h\n"}}}}}'
kubectl rollout status deploy/probe-v1 -n starfleet
```

The annotation must be on the **pod template**, not on the Deployment object, because the sidecar injector reads it when it creates the pod. The change restarts the pods, and the new pods request a two-hour certificate. Read the dates through each version of the probe. The Service `probe` sends a request to either version, so run `chain` a few times and print `-startdate -enddate` after each run.

A certificate with the two-hour lifetime shows a `notAfter` about two hours after `notBefore`. A certificate from `probe-v2` still shows about 24 hours. The `proxyMetadata` field and the `SECRET_TTL` variable are each in the Istio references. The Istio documentation does not give this exact combination as an example, so confirm the dates on your cluster.

## Short lifetime instead of revocation

Istio does not publish a certificate revocation list for workload certificates. The control is the lifetime itself. If the key of one pod leaks, the attacker can use the certificate until it expires, at most 24 hours with the defaults. Deleting the pod ends the use of that key by the pod, but not the validity of the certificate. A shorter lifetime narrows the window. A longer lifetime reduces load on `istiod` and the time a mesh can run if `istiod` is unavailable, because a sidecar keeps using its certificate until it expires.

That last point is the trade-off to state in an exam answer: short lifetimes favour security, long lifetimes favour availability. The default of 24 hours with renewal at 12 hours means a sidecar has about 12 hours of margin to reach `istiod` again before its certificate expires.

## Request and cap

Three examples show how the values combine, with `MAX_WORKLOAD_CERT_TTL` at its default `2160h`:

- A sidecar with the default `SECRET_TTL` of `24h` gets 24 hours.
- A sidecar with `SECRET_TTL: 2h` gets 2 hours, and renews after about 1 hour.
- A sidecar with `SECRET_TTL: 4000h` asks for more than the cap, so the lifetime is limited to `2160h`, which is 90 days.

The cap is set on `istiod`, so only the mesh operator changes it, and a workload owner cannot lengthen the life of a certificate beyond it.

## Lifetime of the intermediate

The lifetime of a workload certificate is capped by the CA that signs it. A certificate cannot outlive its issuer in practice, because verifiers check every certificate in the chain. If the intermediate expires in 730 days, every workload certificate becomes invalid when it does, so renew the intermediate and update `cacerts` before then. The root outlives the intermediate by design.

You can check how long is left on the files you created:

```sh
openssl x509 -in certs/ca-cert.pem -noout -enddate
openssl x509 -in certs/ca-cert.pem -noout -checkend 2592000
```

The second command prints `Certificate will not expire` when the intermediate is valid for at least 30 days more (`2592000` seconds), and `Certificate will expire` otherwise. Its exit code is `0` or `1`, so a script can use it.

## Test a lifetime with checkend

Reading two dates and subtracting them is error-prone. Use `-checkend`, which takes a number of seconds and tests whether the certificate expires within that time:

```sh
openssl x509 -in proxy-cert-1.pem -noout -checkend 14400
```

`14400` seconds is four hours. For a two-hour certificate the command prints `Certificate will expire` and exits with `1`. For a 24-hour certificate it prints `Certificate will not expire` and exits with `0`. The same test works in a script.

## Common pitfalls

> [!WARNING]
> - **Annotating the Deployment object.** The annotation goes in `spec.template.metadata.annotations`.
> - **Expecting a live change.** A new `SECRET_TTL` applies to pods that start after the change.
> - **Asking for more than the maximum.** `istiod` caps the lifetime at `MAX_WORKLOAD_CERT_TTL`, `2160h` by default.
> - **Letting the intermediate expire.** All workload certificates then fail verification.
