#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. The waypoint. This is what `istioctl waypoint apply -n ambient-authz`
#    generates; applying it directly keeps CI deterministic.
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
kubectl -n ambient-authz wait --for=condition=Programmed gateway/waypoint --timeout=300s

# 2. Enrolment. Creating a waypoint and sending traffic through it are two
#    separate steps; this is the second (what --enroll-namespace does).
kubectl label namespace ambient-authz istio.io/use-waypoint=waypoint --overwrite

# 3. The request-level policy. methods and paths need the parsed request, so
#    the waypoint holds it; it attaches with targetRefs to the Service.
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
            paths: ["/notify"]
YAML

# Give istiod time to push the policy to the waypoint before the grader calls it.
sleep 15
