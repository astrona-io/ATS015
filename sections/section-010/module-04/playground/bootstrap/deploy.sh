#!/usr/bin/env bash
# Deploy what the 010-04 playground needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - shuttle (test client, service account "shuttle") and probe v1/v2 (echo
#     service, service account "probe"): the workloads whose certificates you inspect
#   - a STRICT PeerAuthentication for starfleet
# istiod runs with its self-signed CA: there is no cacerts Secret. Creating it is the
# point of the module.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-010-04" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> Shuttle and probe"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml

echo "==> STRICT mTLS (so a TLS client can read the certificate chain a sidecar presents)"
kubectl apply -f manifests/peerauthentication-strict.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s

kubectl get pods -n starfleet
echo "==> Playground ats-015-playground-010-04 ready"
