#!/usr/bin/env bash
# The lab's starting state: the namespace starfleet requires mTLS (namespace-wide
# STRICT), and the probe's DestinationRule was copied from another service with
# its whole trafficPolicy - including tls.mode: DISABLE. Callers in the mesh now
# send plain text to a server that only accepts mTLS, and get 503 UC.
# Fixing the client side (the DestinationRule) is the task - the server is right.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
YAML

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe
  namespace: starfleet
spec:
  host: probe
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST
    tls:
      mode: DISABLE
YAML
echo "==> Lab ats-015-lab-010-02-03 ready"
