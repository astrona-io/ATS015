#!/usr/bin/env bash
# The lab's starting state:
#   - starfleet is STRICT for every ship (namespace policy "default")
#   - the probe has a port exception that does nothing: it names port 8000,
#     the Service port. The proxy only sees the container port, 8080, so the
#     probe stays STRICT and the drifter gets a connection reset.
# Fixing the probe's PeerAuthentication is the task.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
YAML

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  mtls:
    mode: STRICT
  portLevelMtls:
    8000:
      mode: PERMISSIVE
YAML
echo "==> Lab ats-015-lab-010-03-02 ready"
