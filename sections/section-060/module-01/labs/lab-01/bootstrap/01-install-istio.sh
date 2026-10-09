#!/usr/bin/env bash
# Installs Istio 1.30.5 in AMBIENT mode into the lab cluster:
#   Gateway API   the standard CRDs. A waypoint is a Gateway API Gateway, so
#                 "istioctl waypoint apply" needs them.
#   istio-system  istio-base (CRDs), istiod (profile=ambient), istio-cni and
#                 ztunnel, with Helm. No sidecar injection is used.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

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
echo "==> Istio (ambient) ready"
