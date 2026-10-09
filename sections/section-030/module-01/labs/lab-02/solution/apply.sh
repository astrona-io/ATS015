#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. Check tokens from the demo issuer on the probe, read ONLY from ?token=...
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: probe-jwt
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json
    fromParams:
    - token
YAML

# 2. "Token required" written as DENY: refuse every request without a valid
#    request principal. No ALLOW policy, so nothing else is refused.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-require-jwt
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - from:
    - source:
        notRequestPrincipals: ["*"]
YAML
