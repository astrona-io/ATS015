#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# 1. Copy the certificate and key out of the Secret in the wrong namespace, and
#    create the Secret where the gateway pod runs (istio-ingress).
kubectl get secret starfleet-credential -n starfleet \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > "$WORK/tls.crt"
kubectl get secret starfleet-credential -n starfleet \
  -o jsonpath='{.data.tls\.key}' | base64 -d > "$WORK/tls.key"
kubectl create secret tls starfleet-credential -n istio-ingress \
  --cert="$WORK/tls.crt" --key="$WORK/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Serve the right host name on the HTTPS server.
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: starfleet-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - starfleet.example.com
    tls:
      mode: SIMPLE
      credentialName: starfleet-credential
YAML

# Give istiod time to push the credential and the listener to the gateway
# before the grader reads them back.
sleep 15
