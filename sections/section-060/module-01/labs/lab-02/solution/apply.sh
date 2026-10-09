#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# Two L4 rules. Every field is about the caller's identity, so ztunnel
# enforces them with no waypoint. A label selector points at the pods.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cargo-l4
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: cargo
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-bridge
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-l4
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcom
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/starfleet-scout
YAML
