#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# Mesh-wide: the root namespace, no selector.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
YAML

# Namespace-wide: the target namespace, no selector. Overrides the mesh policy here.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mtls-demo
spec:
  mtls:
    mode: PERMISSIVE
YAML

# Workload: the target namespace plus a selector. Narrower still, so it wins.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: notification-strict
  namespace: mtls-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  mtls:
    mode: STRICT
YAML
