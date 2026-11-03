#!/usr/bin/env bash
# Reference: build a root CA and an intermediate CA for Istio's plug-in CA.
# Demo material only: the root key should stay offline in a real setup.
# Writes root-cert.pem, ca-cert.pem, ca-key.pem and cert-chain.pem into ./certs.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs
cd certs

# Root CA
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -key root-key.pem -sha256 -days 3650 \
  -config ../root.cnf -extensions v3_ca -out root-cert.pem

# Intermediate CA, signed by the root
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=Starfleet/CN=Starfleet Intermediate CA" -out ca.csr
openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 730 -sha256 -extfile ../intermediate.ext -out ca-cert.pem

# Chain: intermediate first, then root
cat ca-cert.pem root-cert.pem > cert-chain.pem
openssl verify -CAfile root-cert.pem ca-cert.pem
