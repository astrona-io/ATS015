# Plug In Your Own CA

Plugging in a CA has three steps: create the certificate files, store them in the Secret `cacerts`, and restart `istiod` and the workloads so everything uses the new chain. This chapter does all three with `openssl` and proves the result with `openssl verify`.

<!-- astrona:playground:renew -->

## The four files

`istiod` reads these keys from the Secret `cacerts` in `istio-system`:

| Key | Content |
| --- | --- |
| `ca-cert.pem` | The intermediate CA certificate that signs workload certificates |
| `ca-key.pem` | The private key of that intermediate CA |
| `root-cert.pem` | The root certificate that signed the intermediate |
| `cert-chain.pem` | The chain that sidecars send: the intermediate certificate first, then the root |

A missing key leaves `istiod` unable to use the Secret. The Istio documentation builds the files with a Makefile. This chapter uses `openssl` directly so that each step is visible. The files are demo material: in production the root key stays offline and a CA product such as HashiCorp Vault issues the intermediate.

## Build the root and the intermediate

The playground repository has the reference script `examples/01-plug-in-ca/make-ca.sh` with two small files, `root.cnf` and `intermediate.ext`. The root configuration sets `basicConstraints = critical, CA:TRUE` and `keyUsage = keyCertSign, cRLSign`. The intermediate extension file adds `pathlen:0`, which says that this CA may sign workload certificates but no further CAs.

The script runs these steps:

```sh
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -key root-key.pem -sha256 -days 3650 \
  -config ../root.cnf -extensions v3_ca -out root-cert.pem
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=Starfleet/CN=Starfleet Intermediate CA" -out ca.csr
openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 730 -sha256 -extfile ../intermediate.ext -out ca-cert.pem
cat ca-cert.pem root-cert.pem > cert-chain.pem
```

The first two lines create the root key and a self-signed root certificate. The next three create the intermediate key, a signing request, and the intermediate certificate signed by the root. The last line writes the chain in the order Istio expects. Run the script and check the intermediate against the root:

```sh
./make-ca.sh
openssl verify -CAfile certs/root-cert.pem certs/ca-cert.pem
```

The second command prints `certs/ca-cert.pem: OK`.

## Create the Secret and restart

```sh
cd certs
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem --from-file=ca-key.pem \
  --from-file=root-cert.pem --from-file=cert-chain.pem
```

`istiod` reads the Secret when it starts. On a mesh that is already running, restart it, then restart the workloads. A workload keeps the certificate it already has until it is renewed, so a restart makes each sidecar request a new certificate from the new CA:

```sh
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout status deploy/istiod -n istio-system
kubectl rollout restart deploy -n starfleet
```

The Istio documentation does not describe a restart of `istiod` on a running mesh. Restarting it is a safe way to make it read the Secret on a cluster where `istiod` was already running. On a fresh install, create the Secret before `istiod` starts.

## Prove the chain

Wait until the pods show `2/2`, then read the certificates again and verify the workload certificate against your CA:

```sh
chain
cat ca-cert.pem root-cert.pem > verify-bundle.pem
openssl verify -CAfile verify-bundle.pem proxy-cert-1.pem
openssl x509 -in proxy-cert-1.pem -noout -issuer
```

The verify command prints `proxy-cert-1.pem: OK`, and the issuer is `Starfleet Intermediate CA`. The Istio documentation also compares the root and the intermediate that the sidecar sends with your files. Run `openssl x509 -in proxy-cert-2.pem -noout -fingerprint` and the same command on `ca-cert.pem`: both lines show the same fingerprint when the sidecar sends your intermediate.

Mutual TLS between workloads keeps working after the change, because every workload now holds a certificate from the same new CA. A workload that still holds a certificate from the old self-signed root may fail to verify a peer from the new CA. That is why the restart of the workloads matters.

## Why the intermediate carries pathlen:0

A CA certificate has `basicConstraints` with `CA:TRUE`. The optional `pathlen` limits how many more CA certificates may follow it in a chain. With `pathlen:0`, the intermediate can sign workload (end entity) certificates and cannot sign another CA. If the intermediate key ever leaks, an attacker can mint workload certificates under that intermediate but cannot create a new CA that the verifiers would accept as part of the chain.

The same structure supports several clusters. Create one root, and one intermediate per cluster, each in the `cacerts` Secret of its own cluster. Workloads in the clusters chain to the same root, so they can verify one another across the clusters. The root key stays outside every cluster, and a leaked intermediate affects only its own cluster, which you replace by issuing a new intermediate from the root.

## Go back to the self-signed CA

To undo the change, delete the Secret, restart `istiod`, and restart the workloads:

```sh
kubectl delete secret cacerts -n istio-system
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout restart deploy -n starfleet
```

Without `cacerts`, `istiod` signs with a self-signed root again. After the restart, `chain` shows an issuer from `istiod` and not `Starfleet Intermediate CA`.

## Common pitfalls

> [!WARNING]
> - **A missing file in the Secret.** All four keys are required, with those exact names.
> - **A wrong chain order.** `cert-chain.pem` starts with the intermediate, then the root.
> - **Not restarting the workloads.** Old certificates stay until renewal, so some pods trust the old root and some the new one.
> - **Putting the root key into the cluster.** Only the intermediate key belongs in `cacerts`.
