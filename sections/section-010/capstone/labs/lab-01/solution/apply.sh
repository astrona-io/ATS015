#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. Bring the plain-text caller into the mesh FIRST. The namespace label only
#    affects pods created from now on, so the Deployment has to roll.
kubectl label namespace outside istio-injection=enabled --overwrite
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client --timeout=300s

# 2. Mesh scope: the root namespace, no selector. Applied only after the last
#    plain-text caller has a sidecar.
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

# 3. Identity-based authorization. The principal is the certificate SAN without
#    the spiffe:// scheme. `namespaces` would not do: tester runs in the same
#    namespace.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-by-identity
  namespace: identity-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/identity-demo/sa/booking-sa
YAML

# Give istiod time to push this configuration to every proxy before the grader
# reads it back.
sleep 30
