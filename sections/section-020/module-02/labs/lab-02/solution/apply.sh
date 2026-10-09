#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-read-only
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - to:
    - operation:
        notMethods: ["GET"]
YAML
