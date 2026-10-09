#!/usr/bin/env bash
# Creates the namespace `starfleet` enrolled in AMBIENT mode (no sidecars), the
# Starfleet (bridge, cargo, scout v1-v3, navcom, each with its own service
# account) and the shuttle client (service account "shuttle").
# Creates NONE of the objects the task asks for: no AuthorizationPolicy.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace (ambient)"
kubectl apply -f manifests/namespace.yaml

echo "==> The Starfleet and the shuttle"
kubectl apply -n starfleet -f manifests/starfleet.yaml
kubectl apply -f manifests/shuttle.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet
