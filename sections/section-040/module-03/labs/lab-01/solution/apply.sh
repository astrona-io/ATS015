#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: passthrough-gateway
  namespace: passthrough-demo
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: tls
        protocol: TLS
      hosts:
        - secure.ica.local
      tls:
        mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: passthrough-demo
spec:
  hosts:
    - secure.ica.local
  gateways:
    - passthrough-gateway
  # Passthrough routes on SNI, so this is a tls block, not an http block.
  tls:
    - match:
        - port: 443
          sniHosts:
            - secure.ica.local
      route:
        - destination:
            host: tls-backend
            port:
              number: 8443
YAML
