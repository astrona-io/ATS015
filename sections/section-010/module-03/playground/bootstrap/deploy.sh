#!/usr/bin/env bash
# Deploy what the 010-03 playground needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - the Starfleet: bridge, cargo, scout v1-v3, navcom (Bookinfo with space names)
#   - shuttle (test client) + probe v1/v2 (echo service, Service port 8000,
#     container port 8080)
#   - namespace outpost WITHOUT injection, with the drifter client (1/1):
#     the client that still sends plain-text requests
# No PeerAuthentication is created: starfleet starts in the default
# PERMISSIVE mode, and moving it to STRICT is the module.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-010-03" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet"
kubectl apply -n starfleet -f manifests/starfleet.yaml

echo "==> Shuttle and probe"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml

echo "==> The outpost (no injection, on purpose)"
kubectl apply -f manifests/outpost.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl wait -n outpost --for=condition=Available deploy --all --timeout=300s

kubectl get pods -n starfleet
kubectl get pods -n outpost
echo "==> Playground ats-015-playground-010-03 ready"
