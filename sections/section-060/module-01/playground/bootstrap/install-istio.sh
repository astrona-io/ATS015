#!/usr/bin/env bash
# Install Istio in AMBIENT mode into this playground's kind cluster:
#   Gateway API   the standard CRDs (Gateway, HTTPRoute, GatewayClass, ...).
#                 A waypoint is a Gateway API Gateway, so these are needed
#                 before "istioctl waypoint apply" can work.
#   istio-system  istio-base (Istio CRDs), istiod with the ambient profile,
#                 istio-cni (redirects pod traffic to ztunnel) and ztunnel
#                 (the per-node proxy that does mutual TLS and L4 policy),
#                 all with Helm.
# No ingress gateway and no sidecar injector are used.
# Change the version with:  ISTIO_VERSION=<version> astrona run -c .
set -euo pipefail

# Pin this playground's cluster: use a private kubeconfig, so nothing else that
# switches the global kubectl context meanwhile can redirect these commands.
KCFG="$(mktemp)"; trap 'rm -f "$KCFG"' EXIT
kubectl config view --minify --flatten --context "kind-astro-ats-015-playground-060-01" > "$KCFG"
export KUBECONFIG="$KCFG"

ISTIO_VERSION="${ISTIO_VERSION:-1.30.5}"
# Must be a Gateway API release that this Istio version supports.
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.3.0}"
REPO="https://istio-release.storage.googleapis.com/charts"
# First run pulls images; give Helm time to wait for ready pods.
WAIT=(--wait --timeout 10m)

echo "==> Gateway API CRDs ${GATEWAY_API_VERSION}"
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 || \
  kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
kubectl wait --for=condition=Established --timeout=120s \
  crd/gateways.gateway.networking.k8s.io crd/gatewayclasses.gateway.networking.k8s.io

echo "==> Istio $ISTIO_VERSION: base (CRDs)"
helm upgrade --install istio-base base --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system --create-namespace "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: istiod (ambient profile)"
helm upgrade --install istiod istiod --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system --set profile=ambient "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: istio-cni (ambient profile)"
helm upgrade --install istio-cni cni --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system --set profile=ambient "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: ztunnel"
helm upgrade --install ztunnel ztunnel --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system "${WAIT[@]}"

echo "==> Waiting until the Istio CRDs are registered"
kubectl wait --for=condition=Established crd --all --timeout=120s >/dev/null

echo "==> Waiting for Istio to register the waypoint GatewayClass"
for _ in $(seq 1 60); do
  kubectl get gatewayclass istio-waypoint >/dev/null 2>&1 && break
  sleep 2
done
kubectl get gatewayclass

kubectl get pods -n istio-system
echo "==> Istio (ambient) ready"
