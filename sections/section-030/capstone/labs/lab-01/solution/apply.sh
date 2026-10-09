#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-issuer
  namespace: jwtclaims-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  jwtRules:
    - issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/jwks.json"
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-access
  namespace: jwtclaims-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/notify"]
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

# Give istiod time to push the policies (and the proxies time to fetch the JWKS)
# before the grader sends traffic.
sleep 15
