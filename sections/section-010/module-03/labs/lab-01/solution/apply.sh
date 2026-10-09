#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. Write down the current mode (also the rollback file).
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: PERMISSIVE
YAML

# 2. Bring outside-client into the mesh: label, then restart.
kubectl label namespace outside istio-injection=enabled --overwrite
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client --timeout=300s

# 3. Only now switch the namespace to STRICT.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migrate-demo
spec:
  mtls:
    mode: STRICT
YAML

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. `astrona test` applies and grades in the same second, and
# would otherwise measure the previous state.
sleep 30
