#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. Register the provider: append to the existing mesh configuration, never replace it.
mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}')
new=$(printf '%s\nextensionProviders:\n- name: starfleet-authz\n  envoyExtAuthzHttp:\n    service: ext-authz.starfleet.svc.cluster.local\n    port: "8000"\n    includeRequestHeadersInCheck: ["x-ext-authz"]\n' "$mesh")
kubectl patch configmap istio -n istio-system --type merge \
  -p "$(jq -n --arg m "$new" '{data:{mesh:$m}}')"

# 2. The CUSTOM policy for /headers only.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-ext-authz
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: CUSTOM
  provider:
    name: starfleet-authz
  rules:
    - to:
        - operation:
            paths: ["/headers"]
YAML
sleep 20
