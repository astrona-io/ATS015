#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# An ALLOW policy with no rules allows nothing: the deny-by-default base.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: authz-demo
spec: {}
YAML

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: booking-allow
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: booking-service
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces: ["authz-demo"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/book"]
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-allow
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/authz-demo/sa/booking-sa
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
YAML

# Give the proxies time to receive the new rules before grading.
sleep 30
