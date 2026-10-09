#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-deny
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: DENY
  rules:
  - from:
    - source:
        remoteIpBlocks:
        - 192.168.0.0/16
YAML

# Policy changes take a little while to reach live traffic.
sleep 30
