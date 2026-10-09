#!/usr/bin/env bash
# Creates the planet `starfleet` (sidecar injection on), mesh-wide access logs,
# the Starfleet (bridge, cargo, scout v1-v3, navcom), the shuttle client, the
# probe v1/v2 (Service port 8000 -> container port 8080), and the planet
# `outpost` WITHOUT injection, with the drifter (a client with no sidecar).
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet, the shuttle and the probe"
kubectl apply -n starfleet -f manifests/starfleet.yaml
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml

echo "==> The outpost and the drifter (no sidecar)"
kubectl apply -f manifests/outpost.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl wait -n outpost --for=condition=Available deploy --all --timeout=300s
kubectl get pods -n starfleet
kubectl get pods -n outpost
