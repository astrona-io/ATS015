#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-access
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - to:
    - operation:
        paths: ["/headers"]
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get"]
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        paths: ["/anything/admin"]
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
YAML
