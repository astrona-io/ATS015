#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

NS="ambient-authz"

# 1. The waypoint. This is the object `istioctl waypoint apply -n ambient-authz`
#    creates; applying it directly keeps CI free of istioctl.
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: ambient-authz
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
YAML
kubectl wait --for=condition=Programmed gateway/waypoint -n "$NS" --timeout=300s

# 2. Send the namespace's traffic through it. A waypoint that exists is not a
#    waypoint that receives traffic.
kubectl label namespace "$NS" istio.io/use-waypoint=waypoint --overwrite

# 3. One L7 policy at the waypoint: identity AND method. targetRefs names the
#    Service whose waypoint holds it.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-l7
  namespace: ambient-authz
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: notification-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/ambient-authz/sa/tester-sa
    to:
    - operation:
        methods: ["POST"]
YAML
