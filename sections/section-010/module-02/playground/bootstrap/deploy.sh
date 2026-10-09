#!/usr/bin/env bash
# Deploy what the 010-02 playground needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - the Starfleet: bridge, cargo, scout v1-v3, navcom (Bookinfo with space names)
#   - shuttle (test client in the mesh) + probe v1/v2 (echo service: its
#     /headers answer shows the caller's identity when a request used mTLS)
#   - namespace outpost WITHOUT injection, with the drifter: a client with no
#     sidecar, so everything it sends is plain text
# No PeerAuthentication and no DestinationRule are created: the default mode
# (PERMISSIVE) is in force, and changing it is the module.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-010-02" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet"
kubectl apply -n starfleet -f manifests/starfleet.yaml

echo "==> Shuttle and probe"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml

echo "==> The outpost and the drifter (no sidecar)"
kubectl apply -f manifests/outpost.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl wait -n outpost --for=condition=Available deploy --all --timeout=300s

kubectl get pods -n starfleet
kubectl get pods -n outpost
echo "==> Playground ats-015-playground-010-02 ready"
