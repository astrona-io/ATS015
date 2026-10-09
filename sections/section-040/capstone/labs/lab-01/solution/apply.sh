#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. The terminating credential, in the GATEWAY's namespace, from the material
#    the bootstrap left in /tmp. The passthrough hostname needs no credential.
if [ ! -f /tmp/booking.crt ] || [ ! -f /tmp/booking.key ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/booking.key -out /tmp/booking.crt \
    -subj "/CN=booking.ica.local/O=ica" 2>/dev/null
fi
kubectl -n istio-system create secret tls booking-credential \
  --key=/tmp/booking.key --cert=/tmp/booking.crt \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. One gateway, three listeners, two TLS modes, and two routing sections.
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: tls-demo
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-booking
        protocol: HTTPS
      hosts:
        - booking.ica.local
      tls:
        mode: SIMPLE
        credentialName: booking-credential
    - port:
        number: 443
        name: tls-secure
        protocol: TLS
      hosts:
        - secure.ica.local
      tls:
        mode: PASSTHROUGH
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - booking.ica.local
      tls:
        httpsRedirect: true
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: tls-demo
spec:
  hosts:
    - booking.ica.local
  gateways:
    - edge-gateway
  http:
    - match:
        - uri:
            prefix: /book
      route:
        - destination:
            host: booking-service
            port:
              number: 80
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: tls-demo
spec:
  hosts:
    - secure.ica.local
  gateways:
    - edge-gateway
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

# Give istiod time to push the listeners to the gateway before the grader calls it.
sleep 15
