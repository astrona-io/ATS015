#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W"

cat > root.cnf <<'CNF'
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
CNF
cat > intermediate.ext <<'EXT'
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
EXT

# 1. Root and intermediate CA
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -key root-key.pem -sha256 -days 3650 -config root.cnf -extensions v3_ca -out root-cert.pem
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=Starfleet/CN=Starfleet Intermediate CA" -out ca.csr
openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 730 -sha256 -extfile intermediate.ext -out ca-cert.pem
cat ca-cert.pem root-cert.pem > cert-chain.pem

# 2. The Secret: only the intermediate key goes into the cluster
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem --from-file=ca-key.pem \
  --from-file=root-cert.pem --from-file=cert-chain.pem

# 3. istiod reads the Secret at start; workloads need new certificates
kubectl rollout restart deploy/istiod -n istio-system
kubectl rollout status deploy/istiod -n istio-system --timeout=300s

# 4. Two-hour lifetime for probe-short, set on the pod template (this restarts its pods)
kubectl patch deploy/probe-short -n ca-demo --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"proxy.istio.io/config":"proxyMetadata:\n  SECRET_TTL: 2h\n"}}}}}'
kubectl rollout restart deploy/probe-long deploy/shuttle -n ca-demo
kubectl rollout status deploy/probe-short -n ca-demo --timeout=300s
kubectl rollout status deploy/probe-long -n ca-demo --timeout=300s
kubectl rollout status deploy/shuttle -n ca-demo --timeout=300s
sleep 20
