#!/usr/bin/env bash
# Creates the planet `starfleet` (sidecar injection on), mesh-wide access logs,
# the Starfleet (bridge, cargo, scout v1-v3, navcom), the shuttle client, and a
# Gateway plus VirtualService that send starfleet.example.com to the bridge.
# Creates NO AuthorizationPolicy: writing it is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet and the shuttle"
kubectl apply -n starfleet -f manifests/starfleet.yaml
kubectl apply -f manifests/shuttle.yaml

echo "==> The arrival gate for starfleet.example.com"
kubectl apply -f manifests/gateway-starfleet.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet
