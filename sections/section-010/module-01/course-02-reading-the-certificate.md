# Part 2 — Reading the certificate a proxy holds

> Prerequisite: [Part 1 — How a workload gets its identity](./course-01-how-identity-is-issued.md). Next: [Part 3 — From SAN to policy principal](./course-03-principals-rotation-trust-domain.md).

Part 1 ended with a certificate sitting in Envoy's memory. This part opens it. The skill is worth having on its own — when a policy denies traffic you expected to allow, reading the caller's actual identity off its actual certificate settles in one pass what guessing never does.

## `istioctl proxy-config` is a command family

Most Istio debugging commands ask the control plane what it *intends*. `istioctl proxy-config` asks a **running proxy** what it currently holds, which is a different question and usually the more useful one.

The shape is always the same:

```text
istioctl proxy-config <what> <pod-or-deployment> -n <namespace> [-o json]
```

`<what>` is the Envoy concept you want, and learning them as a set is easier than learning the commands one at a time, because each maps to a stage of how Envoy handles a connection:

| `<what>` | Envoy's question | You use it to check |
| --- | --- | --- |
| `listener` | what am I listening on, and how? | ports, TLS requirements, filter chains |
| `route` | given an HTTP request, where does it go? | `VirtualService` results |
| `cluster` | what named destinations do I know? | service discovery, subsets |
| `endpoint` | which addresses back that destination? | whether pods are healthy and registered |
| `secret` | what TLS material do I hold? | identity, gateway credentials |

This part uses `secret`. Later modules use `listener` to prove a port requires mTLS and to find the RBAC and JWT filters, and the same syntax carries across unchanged.

There is one substitution to know: the target can be a pod name or, more conveniently, `deploy/<name>`, in which case `istioctl` picks a pod from that Deployment for you.

## Every proxy holds two secrets, with different jobs

Ask a workload proxy what TLS material it has and you get two entries, not one. They are easy to confuse and they do opposite things.

> [!TIP]
> **Try it — list the certificates the booking proxy holds**
>
> ```sh
> istioctl proxy-config secret deploy/booking-service-v1 -n identity-demo
> ```
>
> Expect something like:
>
> ```text
> RESOURCE NAME     TYPE           STATUS     VALID CERT     SERIAL NUMBER        NOT AFTER                NOT BEFORE
> default           Cert Chain     ACTIVE     true           28516...             2026-09-28T09:14:52Z     2026-09-27T09:12:52Z
> ROOTCA            CA             ACTIVE     true           17743...             2036-09-25T08:41:14Z     2026-09-27T08:41:14Z
> ```
>
> Two entries, with different jobs. `default` is this workload's own leaf certificate — its identity, the thing it presents. `ROOTCA` is the mesh CA's certificate, which the proxy uses to verify *other* workloads' certificates. Note the `NOT AFTER` on `default`: roughly a day away, while `ROOTCA` runs for years.

The two-entry layout is the mutual in mutual TLS, made concrete. Every handshake needs both halves:

```text
  booking-service                         notification-service
  ───────────────                         ─────────────────────
  presents `default`         ──────▶      verifies it against ROOTCA
  verifies against ROOTCA    ◀──────      presents its own `default`
```

Which is also why the two entries have such different lifetimes. The leaf is short-lived because it is handed out constantly and a leak should expire quickly. The root is long-lived because rotating it means re-establishing trust across the entire mesh at once.

In Envoy's own vocabulary these are a **tls_certificate** (what I present) and a **validation_context** (what I check others against). Those names show up in `-o json` output and in gateway configuration later in the course, where the same two roles reappear as `tls.crt`/`tls.key` and `ca.crt` inside one Kubernetes secret.

## Getting to the SAN

The summary table does not show the identity, and the identity is the thing you came for. It lives in the certificate's **SAN** — Subject Alternative Name — as a URI entry, which means you have to extract the certificate and decode it.

`-o json` returns the full Envoy secret structure. The leaf certificate is base64-encoded inside it, under a path that reads verbosely but is mechanical:

```text
dynamicActiveSecrets[]            all secrets the proxy has been pushed
  └─ name == "default"            the leaf, as opposed to "ROOTCA"
       └─ secret
            └─ tlsCertificate
                 └─ certificateChain
                      └─ inlineBytes     base64 PEM
```

The Python one-liner below is only walking that path and base64-decoding the last step. Nothing about it is Istio-specific, and if you prefer `jq` it translates directly.

> [!TIP]
> **Try it — decode the leaf certificate and find the identity**
>
> ```sh
> istioctl proxy-config secret deploy/booking-service-v1 -n identity-demo -o json \
>   | python3 -c "import sys,json,base64; d=json.load(sys.stdin); \
>       c=[s for s in d['dynamicActiveSecrets'] if s['name']=='default'][0]; \
>       print(base64.b64decode(c['secret']['tlsCertificate']['certificateChain']['inlineBytes']).decode())" \
>   > /tmp/workload.crt
>
> openssl x509 -in /tmp/workload.crt -noout -text | grep -A1 'Subject Alternative Name'
> ```
>
> Expect something like:
>
> ```text
>             X509v3 Subject Alternative Name: critical
>                 URI:spiffe://cluster.local/ns/identity-demo/sa/booking-sa
> ```
>
> That URI is the identity, issued by istiod's CA and presented on every connection this pod makes. `/tmp/workload.crt` is now a plain PEM file on the playground machine, so the rest of `openssl`'s output — issuer, key, validity window — is available too.

Two details in that output repay a second look.

**The SAN is marked `critical`.** In X.509, a critical extension is one a verifier must understand or reject the certificate outright. Marking the SAN critical is how Istio ensures nothing treats a mesh certificate as an ordinary server certificate and quietly ignores the identity in it.

**The Subject is empty.** Conventional TLS certificates put a name in the Subject `CN`; mesh certificates leave it blank and carry everything in the SAN URI. If you go looking for the identity in the Subject line — a reasonable instinct from web PKI — you will find nothing and conclude something is broken.

## Reading it the other way: the issuer chain

`-noout -text` prints a lot. Two other `openssl` flags answer narrower questions faster, and both are worth having in reach:

```sh
openssl x509 -in /tmp/workload.crt -noout -issuer -subject
openssl x509 -in /tmp/workload.crt -noout -dates
```

The issuer names the CA that signed this leaf — in a default install, istiod's own. This is the value that changes when a mesh is configured with an external or intermediate CA, and comparing it across two workloads is the quickest way to spot a mesh where half the workloads were issued by something else. `-dates` is [Part 3](./course-03-principals-rotation-trust-domain.md)'s subject.

> *`istioctl proxy-config` asks a running proxy what it actually holds; every workload holds exactly two things — the identity it presents, and the root it checks everyone else against.*

## Reference

- [`istioctl proxy-config secret`](https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config-secret) — the full flag set, including `-o json`, which is what makes the SAN reachable.
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/) — describes what the proxy is issued and why the root is distributed alongside the leaf.
- `openssl x509 -help` — the local reference for `-text`, `-subject`, `-issuer` and `-dates`; the `x509` subcommand is the one that reads certificates rather than making them.
