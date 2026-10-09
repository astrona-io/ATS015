#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
# Uses the PKI that bootstrap/02-seed-workloads.sh wrote to /tmp.
set -euo pipefail

# MUTUAL needs three keys: tls.crt / tls.key are what the gateway SHOWS, and
# ca.crt is what it CHECKS CLIENTS AGAINST. `kubectl create secret tls` has no
# CA flag, so build a generic secret with explicit key names.
kubectl -n istio-system create secret generic booking-credential-mtls \
  --from-file=tls.crt=/tmp/booking.crt \
  --from-file=tls.key=/tmp/booking.key \
  --from-file=ca.crt=/tmp/ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: booking-gateway
  namespace: mtlsedge-demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - booking.ica.local
    tls:
      mode: MUTUAL
      credentialName: booking-credential-mtls
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: mtlsedge-demo
spec:
  hosts:
  - booking.ica.local
  gateways:
  - booking-gateway
  http:
  - match:
    - uri:
        prefix: /book
    route:
    - destination:
        host: booking-service
        port:
          number: 80
YAML
