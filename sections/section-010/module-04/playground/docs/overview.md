# Overview: Workload Certificates (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Istio
and two workloads, and then waits. There is no task, no `astrona submit` and
no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm (`istio-base` and `istiod` only).
  `istiod` is Istio's control plane. It also runs a certificate authority (CA)
  that signs a certificate for every workload.
- Namespace **`starfleet`**, labelled `istio-injection=enabled`, with `shuttle`
  (a client) and **`probe`** v1 and v2 (an HTTP echo server on port `8000`).
- A **`PeerAuthentication` named `default` in `starfleet`, mode `STRICT`**.
- **No `cacerts` Secret.** `istiod` created its own self-signed root certificate.
  Its public part is in the ConfigMap `istio-ca-root-cert` of each namespace.

You need `openssl` on your own machine for the exercises.

## Helpers

Paste this once in each new terminal. It reads the certificate chain that the
`probe` sidecar presents and saves each certificate as `proxy-cert-1.pem`,
`proxy-cert-2.pem` and so on, in the current directory:

```sh
chain() {
  kubectl exec -n starfleet deploy/shuttle -c istio-proxy -- \
    openssl s_client -showcerts -connect probe.starfleet:8000 </dev/null 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/{n++; f=1} f{print > ("proxy-cert-" n ".pem")} /END CERTIFICATE/{f=0}'
}
```

`proxy-cert-1.pem` is the certificate of the `probe` workload. Print its
dates and issuer with
`openssl x509 -in proxy-cert-1.pem -noout -dates -issuer`.

## Things to try

- Run `chain` and read the issuer and validity dates of `proxy-cert-1.pem`.
- Run `examples/01-plug-in-ca/make-ca.sh`, create the Secret `cacerts` from the
  files in `certs/`, restart `istiod` and the workloads, run `chain` again and
  compare the issuer.
- Check the chain with `openssl verify`.
- Give the `probe` a shorter certificate lifetime with an annotation and compare
  the `notAfter` date.

## Start over without a new cluster

```sh
kubectl delete secret cacerts -n istio-system
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout restart deploy -n starfleet
```

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old one
  is still there: `astrona destroy ats-015-playground-010-04`, then run again.
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-010-04`.
- A pod in `starfleet` shows `1/1`: it has no sidecar. Run
  `kubectl rollout restart deploy -n starfleet`.
- `chain` saves nothing: wait until `shuttle` and `probe` show `2/2`.

## When you're done

```sh
astrona destroy ats-015-playground-010-04
```

## Practice tasks

Two exam-style tasks. Paste the helper first.

### Task 1: make istiod sign with your own root

> Create a root CA and an intermediate CA. Make `istiod` sign workload
> certificates with the intermediate CA. Prove that the `probe` certificate
> verifies against your CA.

<details><summary>Solution</summary>

```sh
cd examples/01-plug-in-ca && ./make-ca.sh && cd certs
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem --from-file=ca-key.pem \
  --from-file=root-cert.pem --from-file=cert-chain.pem
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout status deploy/istiod -n istio-system
kubectl rollout restart deploy -n starfleet
kubectl rollout status deploy/probe-v1 -n starfleet
```

Wait until the pods show `2/2`, then run `chain` and verify the first certificate:

```sh
cat ca-cert.pem root-cert.pem > verify-bundle.pem
openssl verify -CAfile verify-bundle.pem proxy-cert-1.pem
```

The result is `proxy-cert-1.pem: OK`. Before the change, the same command fails
because the old certificate was signed by the self-signed root of `istiod`.

</details>

### Task 2: shorten the lifetime of one workload certificate

> Make the certificate of `probe-v1` valid for about two hours, and leave the
> other workloads at the default.

<details><summary>Solution</summary>

Patch the pod template annotation, which also restarts the pods of `probe-v1`:

```sh
kubectl patch deploy/probe-v1 -n starfleet --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"proxy.istio.io/config":"proxyMetadata:\n  SECRET_TTL: 2h\n"}}}}}'
kubectl rollout status deploy/probe-v1 -n starfleet
```

Run `chain` and read the dates. Because the Service `probe` selects both
versions, run it a few times and compare `notAfter` in each result: the
`probe-v1` certificate ends about two hours after `notBefore`, and the `probe-v2`
certificate about 24 hours after it.

</details>
