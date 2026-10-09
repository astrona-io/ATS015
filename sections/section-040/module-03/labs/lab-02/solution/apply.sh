#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
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
    - vault.starfleet.example.com
    tls:
      mode: PASSTHROUGH
YAML

# The seed used kubectl apply too, so this apply drops the old http block
# (it is in the last-applied configuration and missing here).
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
  tls:
  - match:
    - port: 443
      sniHosts:
      - vault.starfleet.example.com
    route:
    - destination:
        host: tls-backend
        port:
          number: 8443
YAML
