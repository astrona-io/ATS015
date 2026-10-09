#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
# Replaces the gate's secret so ca.crt is the fleet's CA (example.com),
# keeping the server certificate and key.
set -euo pipefail

CERT_DIR="/tmp/ats-015-lab-040-02-02"

kubectl create -n istio-ingress secret generic starfleet-credential-mutual \
  --from-file=tls.key="$CERT_DIR/starfleet.example.com.key" \
  --from-file=tls.crt="$CERT_DIR/starfleet.example.com.crt" \
  --from-file=ca.crt="$CERT_DIR/example.com.crt" \
  --dry-run=client -o yaml | kubectl apply -f -
