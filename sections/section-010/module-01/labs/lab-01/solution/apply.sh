#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# STRICT mTLS for the whole namespace: every caller must show its badge.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: identity-demo
spec:
  mtls:
    mode: STRICT
YAML

# The principal is the certificate SAN with the spiffe:// scheme removed.
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

# Give istiod time to push the policies to every proxy before the grader
# sends traffic; open connections can keep the old rules for a while.
sleep 30
