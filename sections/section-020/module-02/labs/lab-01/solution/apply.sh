#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. The service's normal call. By existing, this ALLOW also turns on
#    default-deny for everything it does not name.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-notify
  namespace: deny-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces: ["deny-demo"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
YAML

# 2. The backstop. `/admin*` is a prefix match: `/admin` alone would leave
#    `/admin/users` reachable. No `from`, so it covers every caller.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-admin
  namespace: deny-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: DENY
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
YAML

# 3. The careless ALLOW the task asks for. It changes nothing: DENY is checked
#    first and ends the decision on a match, so this policy is never read.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-admin-attempt
  namespace: deny-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - to:
        - operation:
            paths: ["/admin*"]
YAML
