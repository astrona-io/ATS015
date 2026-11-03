# Solution Walkthrough

Status: **UNTESTED.** The steps follow the Istio documentation and were never run on a cluster, so this walkthrough shows no command output. Compare your results with the descriptions in each step.

You need four things: a root and an intermediate CA, the Secret `cacerts`, new certificates for all workloads, and a short lifetime for `probe-short`.

---

## Step 1: Paste a helper that reads a chain

```sh
chain() {
  kubectl exec -n ca-demo deploy/shuttle -c istio-proxy -- \
    openssl s_client -showcerts -connect "$1.ca-demo:8000" </dev/null 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/{n++; f=1} f{print > ("'"$1"'-cert-" n ".pem")} /END CERTIFICATE/{f=0}'
}
chain probe-long
openssl x509 -in probe-long-cert-1.pem -noout -issuer -dates
```

`chain probe-long` saves `probe-long-cert-1.pem`, the workload certificate. Its issuer names the self-signed CA of `istiod`, and `notAfter` is about 24 hours after `notBefore`.

## Step 2: Create the root and the intermediate

In an empty directory, save this as `root.cnf`:

```
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca
[dn]
O = Starfleet
CN = Starfleet Root CA
[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
```

Save this as `intermediate.ext`:

```
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
```

Create the root, then the intermediate signed by the root, then the chain file:

```sh
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -key root-key.pem -sha256 -days 3650 -config root.cnf -extensions v3_ca -out root-cert.pem
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=Starfleet/CN=Starfleet Intermediate CA" -out ca.csr
openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial -days 730 -sha256 -extfile intermediate.ext -out ca-cert.pem
cat ca-cert.pem root-cert.pem > cert-chain.pem
openssl verify -CAfile root-cert.pem ca-cert.pem
```

The last command confirms that the intermediate is signed by the root.

## Step 3: Create the Secret

Only the intermediate key goes into the cluster. `root-key.pem` stays on your machine:

```sh
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem --from-file=ca-key.pem \
  --from-file=root-cert.pem --from-file=cert-chain.pem
```

## Step 4: Restart istiod and the workloads

`istiod` reads the Secret when it starts. Restart it first, then the workloads, so each sidecar requests a certificate from the new CA:

```sh
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout status deploy/istiod -n istio-system
kubectl rollout restart deploy -n ca-demo
```

## Step 5: Shorten probe-short

The annotation goes on the pod template. Patching it restarts the pods of `probe-short`:

```sh
kubectl patch deploy/probe-short -n ca-demo --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"proxy.istio.io/config":"proxyMetadata:\n  SECRET_TTL: 2h\n"}}}}}'
kubectl rollout status deploy/probe-short -n ca-demo
```

## Step 6: Prove it

Wait until all pods in `ca-demo` show `2/2`. Then read both chains and check them:

```sh
chain probe-long
chain probe-short
cat ca-cert.pem root-cert.pem > bundle.pem
openssl verify -CAfile bundle.pem probe-long-cert-1.pem
openssl verify -CAfile bundle.pem probe-short-cert-1.pem
openssl x509 -in probe-short-cert-1.pem -noout -checkend 14400
openssl x509 -in probe-long-cert-1.pem -noout -checkend 14400
```

Expected: both `openssl verify` lines end in `OK`. The `probe-short` check prints that the certificate will expire and exits with `1`. The `probe-long` check prints that it will not expire and exits with `0`.

If `verify` fails for a workload, its pod still holds a certificate from the old CA: restart the pod and wait. If `probe-short` still shows a 24-hour lifetime, check that the annotation is under `spec.template.metadata.annotations`, not on the Deployment itself.

## Submit

```sh
astrona submit -c sections/section-010/module-04/labs/lab-01
```
