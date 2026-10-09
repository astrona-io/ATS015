#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: jwt-claims
  namespace: jwtclaims-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    # Any authenticated user may notify.
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
    # Only members of group1 may reach the admin path.
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/admin"]
      when:
        - key: request.auth.claims[groups]
          values: ["group1"]
YAML
