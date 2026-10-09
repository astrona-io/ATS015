#!/usr/bin/env bash
# Deploy what playground ats-015-playground-040-01 needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - the Starfleet: bridge, cargo, scout v1-v3, navcom (Bookinfo with space names)
#   - shuttle (test client)
# No certificates, no TLS Secret, no Gateway and no VirtualService are created:
# making them is the module. The certificates are made with openssl on the
# learner's own machine.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-040-01" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet"
kubectl apply -n starfleet -f manifests/starfleet.yaml

echo "==> Shuttle"
kubectl apply -f manifests/shuttle.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s

kubectl get pods -n starfleet
echo "==> Playground ats-015-playground-040-01 ready"
