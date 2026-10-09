#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: api-office-only
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - to:
    - operation:
        hosts: ["starfleet.example.com"]
        paths: ["/api/v1/products*"]
    from:
    - source:
        notRemoteIpBlocks: ["203.0.113.0/24"]
YAML

# Policy changes take a little while to reach live traffic.
sleep 30
