#!/usr/bin/env bash
# The lab's starting state: a passthrough setup for tls-backend that applies
# cleanly and routes nothing. Two faults:
#   1. the Gateway vault-gateway listens for "valt.starfleet.example.com"
#      (one letter missing), not vault.starfleet.example.com
#   2. the VirtualService tls-backend uses an http block, which cannot match an
#      encrypted stream; it needs a tls block that matches sniHosts
# Fixing both is the task. Do not change tls-backend.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: vault-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - valt.starfleet.example.com
    tls:
      mode: PASSTHROUGH
YAML

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tls-backend
  namespace: starfleet
spec:
  hosts:
  - vault.starfleet.example.com
  gateways:
  - vault-gateway
  http:
  - route:
    - destination:
        host: tls-backend
        port:
          number: 8443
YAML
echo "==> Lab ats-015-lab-040-03-02 ready"
