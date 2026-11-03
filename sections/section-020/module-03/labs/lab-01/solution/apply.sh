#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. One caller, two ports. Port 9002 matches no rule, so default-deny closes it.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-allow-shuttle
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/starfleet/sa/shuttle"]
      to:
        - operation:
            ports: ["9000", "9001"]
YAML

# 2. Close 9001 for everyone. DENY is checked before ALLOW and names a port only.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-deny-9001
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: DENY
  rules:
    - to:
        - operation:
            ports: ["9001"]
YAML
sleep 15
