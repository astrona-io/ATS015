#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. Check tokens from the demo issuer on notification-service.
#    Alone, this still lets a request with no token through.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-demo
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  jwtRules:
    - issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
YAML

# 2. Require a token: this ALLOW policy refuses everything it does not allow,
#    and only a validated token produces a request principal to match.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: jwt-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
YAML
