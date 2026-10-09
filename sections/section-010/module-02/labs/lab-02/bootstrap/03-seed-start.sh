#!/usr/bin/env bash
# The lab's starting state: the whole mesh requires mTLS (mesh-wide STRICT in
# the root namespace). The drifter, which has no sidecar, is refused by every
# ship. Opening one port of the probe for it is the task.
set -euo pipefail

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
echo "==> Lab ats-015-lab-010-02-02 ready"
