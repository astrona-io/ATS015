#!/usr/bin/env bash
# Deploy what the 020-02 playground needs (runs after install-istio.sh):
#   - namespace starfleet (sidecar injection) + mesh-wide access logs
#   - the Starfleet: bridge, cargo, scout v1-v3, navcom (Bookinfo with space
#     names), each with its own service account (starfleet-bridge, ...)
#   - shuttle (test client, service account "shuttle"), probe v1/v2 (echo
#     service, service account "probe") and fortio (no service account of its
#     own, so it runs as "default"): two callers with two different identities
#   - namespace outpost without injection, with the drifter: no sidecar, so no
#     certificate and no identity
#   - a STRICT PeerAuthentication for starfleet: the precondition, so every
#     caller's identity is verified and can be used in a policy
# No AuthorizationPolicy: writing them is the point of the module.
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-020-02" > "$KCFG"
export KUBECONFIG="$KCFG"
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The Starfleet"
kubectl apply -n starfleet -f manifests/starfleet.yaml

echo "==> Shuttle, probe and fortio"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml
kubectl apply -n starfleet -f manifests/fortio.yaml

echo "==> The outpost and the drifter (no sidecar)"
kubectl apply -f manifests/outpost.yaml

echo "==> STRICT mTLS for starfleet (precondition)"
kubectl apply -f manifests/peerauthentication-strict.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl wait -n outpost --for=condition=Available deploy --all --timeout=300s

kubectl get pods -n starfleet
kubectl get pods -n outpost
echo "==> Playground ats-015-playground-020-02 ready"
