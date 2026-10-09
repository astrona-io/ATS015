#!/usr/bin/env bash
# Creates the planet `starfleet` (sidecar injection on), mesh-wide access logs,
# the Starfleet (bridge, cargo, scout v1-v3, navcom), the shuttle client and a
# STRICT PeerAuthentication, so every caller carries a checked identity.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet and the shuttle"
kubectl apply -n starfleet -f manifests/starfleet.yaml
kubectl apply -f manifests/shuttle.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s

echo "==> STRICT mTLS for starfleet (the precondition)"
kubectl apply -f manifests/peerauthentication-strict.yaml

kubectl get pods -n starfleet
