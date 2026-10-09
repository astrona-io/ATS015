#!/usr/bin/env bash
# Deploy what the 040-03 playground needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - the Starfleet: bridge, cargo, scout v1-v3, navcom (Bookinfo with space names)
#   - shuttle (test client inside the mesh)
#   - tls-backend: nginx with its OWN self-signed certificate,
#     serving HTTPS itself on port 8443
#   - prerequisite: manifests/bridge-gateway.yaml, the bridge behind the gateway
#     over plain HTTP at starfleet.example.com (port 80)
# No passthrough Gateway, no TLS secret: writing them is the module.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-040-03" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet"
kubectl apply -n starfleet -f manifests/starfleet.yaml

echo "==> Shuttle and the vault (tls-backend)"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/tls-backend.yaml

echo "==> Prerequisites: the bridge behind the gate (HTTP, port 80)"
kubectl apply -f manifests/bridge-gateway.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s

kubectl get pods -n starfleet
echo "==> Playground ats-015-playground-040-03 ready"
